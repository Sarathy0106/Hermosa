/**
 * Hermosa Music Recommendation Engine
 * 
 * Multi-Factor Hybrid Algorithm:
 * 1. Multi-tier Candidate Generation (API suggestions graph, artist catalog, mood/genre expansion)
 * 2. Multi-feature Vector Scoring (Artist similarity, Language affinity, Era proximity decay, Popularity weighting)
 * 3. User Session & History Profile (Positive decay weighting, anti-fatigue repetition filter)
 * 4. Maximal Marginal Relevance (MMR) Diversity Re-ranking (prevents artist monopoly, ensures smooth flow)
 */

const SAAVN_BASE = process.env.SAAVN_API_URL || "https://resona-saavn-api.vercel.app/api";

// Simple in-memory cache for API responses (5 min TTL)
const cache = new Map();
const CACHE_TTL_MS = 5 * 60 * 1000;
const UPSTREAM_TIMEOUT_MS = 8000;

async function fetchJson(url) {
  const now = Date.now();
  if (cache.has(url)) {
    const entry = cache.get(url);
    if (now - entry.timestamp < CACHE_TTL_MS) {
      return entry.data;
    }
  }

  try {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), UPSTREAM_TIMEOUT_MS);
    let res;
    try {
      res = await fetch(url, {
        headers: { "User-Agent": "Hermosa-Recommender/1.0" },
        signal: controller.signal
      });
    } finally {
      clearTimeout(timer);
    }
    if (!res.ok) return null;
    const json = await res.json();
    if (json && json.success) {
      cache.set(url, { timestamp: now, data: json.data });
      return json.data;
    }
    return null;
  } catch (err) {
    console.error(`[Recommender] Fetch error for ${url}:`, err.message);
    return null;
  }
}

/**
 * Extract clean metadata features from raw song object
 */
function extractFeatures(song) {
  if (!song) return null;
  
  const id = song.id || "";
  const title = (song.name || song.title || "").trim();
  const language = (song.language || "unknown").toLowerCase();
  const year = parseInt(song.year || "0", 10) || 0;
  const playCount = parseInt(song.playCount || "0", 10) || 0;
  const duration = parseInt(song.duration || "0", 10) || 0;
  
  const primaryArtists = [];
  const allArtists = [];
  
  if (song.artists) {
    if (Array.isArray(song.artists.primary)) {
      for (const a of song.artists.primary) {
        if (a.name) primaryArtists.push(a.name.toLowerCase().trim());
      }
    }
    if (Array.isArray(song.artists.all)) {
      for (const a of song.artists.all) {
        if (a.name) allArtists.push(a.name.toLowerCase().trim());
      }
    }
  } else if (typeof song.artists === "string") {
    const names = song.artists.split(",").map(n => n.toLowerCase().trim()).filter(Boolean);
    primaryArtists.push(...names);
    allArtists.push(...names);
  }

  const albumName = (song.album?.name || song.albumName || "").toLowerCase().trim();
  const albumId = song.album?.id || song.albumId || "";

  return {
    id,
    title,
    language,
    year,
    playCount,
    duration,
    primaryArtists,
    allArtists,
    albumName,
    albumId,
    raw: song
  };
}

/**
 * Calculate similarity between candidate song and seed song [0.0, 1.0]
 */
function computeSongSimilarity(candidate, seed) {
  if (!candidate || !seed) return 0;
  if (candidate.id === seed.id) return 1.0;

  let score = 0;

  // 1. Language Match (Weight: 0.35)
  if (candidate.language && seed.language && candidate.language === seed.language) {
    score += 0.35;
  } else if (candidate.language === "english" || seed.language === "english") {
    score += 0.05; // slight bridge for English cross-over
  }

  // 2. Artist Overlap (Weight: 0.35)
  const seedPrimarySet = new Set(seed.primaryArtists);
  const candPrimarySet = new Set(candidate.primaryArtists);
  let primaryIntersection = 0;
  for (const a of candPrimarySet) {
    if (seedPrimarySet.has(a)) primaryIntersection++;
  }

  if (primaryIntersection > 0) {
    score += 0.35 * Math.min(1.0, primaryIntersection / Math.max(1, seedPrimarySet.size));
  } else {
    // Check all artists (composers, lyricists, featured)
    const seedAllSet = new Set(seed.allArtists);
    let allIntersection = 0;
    for (const a of candidate.allArtists) {
      if (seedAllSet.has(a)) allIntersection++;
    }
    if (allIntersection > 0) {
      score += 0.20 * Math.min(1.0, allIntersection / Math.max(1, seedAllSet.size));
    }
  }

  // 3. Release Era / Year Proximity (Weight: 0.15)
  if (candidate.year > 0 && seed.year > 0) {
    const diff = Math.abs(candidate.year - seed.year);
    // Exponential decay: delta of 3 years = 0.65, delta of 10 years = 0.23
    const eraScore = Math.exp(-diff / 7.0);
    score += 0.15 * eraScore;
  } else {
    score += 0.07; // neutral default
  }

  // 4. Album match bonus (Weight: 0.05)
  if (candidate.albumId && seed.albumId && candidate.albumId === seed.albumId) {
    score += 0.05;
  }

  // 5. Popularity signal (Weight: 0.10)
  if (candidate.playCount > 0) {
    // Log scale from 1k to 100M
    const logPlay = Math.log10(Math.max(100, candidate.playCount));
    const normalizedPop = Math.min(1.0, Math.max(0, (logPlay - 3) / 5)); // 1k=0, 100M=1
    score += 0.10 * normalizedPop;
  } else {
    score += 0.05;
  }

  return Math.min(1.0, score);
}

/**
 * Fetch candidate songs from multiple sources
 */
async function generateCandidates(seedSong, options = {}) {
  const { history = [], favorites = [], excludeIds = new Set() } = options;
  const candidatesMap = new Map();

  const addCandidate = (song, sourceWeight = 1.0) => {
    if (!song || !song.id) return;
    if (excludeIds.has(song.id)) return;
    if (!candidatesMap.has(song.id)) {
      candidatesMap.set(song.id, {
        features: extractFeatures(song),
        sourceWeight,
        raw: song
      });
    }
  };

  const tasks = [];

  // Source 1: Direct JioSaavn suggestions endpoint for seed song
  if (seedSong.id) {
    tasks.push(
      fetchJson(`${SAAVN_BASE}/songs/${seedSong.id}/suggestions`).then(list => {
        if (Array.isArray(list)) {
          for (const s of list) addCandidate(s, 1.2);
        }
      })
    );
  }

  // Source 2: Primary artist top search query
  if (seedSong.primaryArtists && seedSong.primaryArtists.length > 0) {
    const mainArtist = seedSong.primaryArtists[0];
    const artistQuery = encodeURIComponent(mainArtist);
    tasks.push(
      fetchJson(`${SAAVN_BASE}/search/songs?query=${artistQuery}&limit=15`).then(res => {
        const list = res?.results || (Array.isArray(res) ? res : []);
        for (const s of list) addCandidate(s, 1.0);
      })
    );
  }

  // Source 3: Language + Genre / Vibe cluster search
  if (seedSong.language) {
    const lang = seedSong.language;
    const searchQueries = [
      `${lang} hits`,
      `${lang} trending`,
      `${lang} romantic hits`
    ];
    const randomQuery = searchQueries[Math.floor(Math.random() * searchQueries.length)];
    tasks.push(
      fetchJson(`${SAAVN_BASE}/search/songs?query=${encodeURIComponent(randomQuery)}&limit=15`).then(res => {
        const list = res?.results || (Array.isArray(res) ? res : []);
        for (const s of list) addCandidate(s, 0.85);
      })
    );
  }

  // Source 4: User history artist discovery (if available)
  if (Array.isArray(history) && history.length > 0) {
    const recentHistory = history.slice(0, 3);
    for (const hSong of recentHistory) {
      const hFeatures = extractFeatures(hSong);
      if (hFeatures && hFeatures.id && hFeatures.id !== seedSong.id) {
        tasks.push(
          fetchJson(`${SAAVN_BASE}/songs/${hFeatures.id}/suggestions`).then(list => {
            if (Array.isArray(list)) {
              for (const s of list) addCandidate(s, 0.9);
            }
          })
        );
      }
    }
  }

  // Source 5: User favorites affinity (if available)
  if (Array.isArray(favorites) && favorites.length > 0) {
    const randomFav = favorites[Math.floor(Math.random() * favorites.length)];
    const fFeatures = extractFeatures(randomFav);
    if (fFeatures && fFeatures.id && fFeatures.id !== seedSong.id) {
      tasks.push(
        fetchJson(`${SAAVN_BASE}/songs/${fFeatures.id}/suggestions`).then(list => {
          if (Array.isArray(list)) {
            for (const s of list) addCandidate(s, 0.95);
          }
        })
      );
    }
  }

  await Promise.allSettled(tasks);

  return Array.from(candidatesMap.values());
}

/**
 * Maximal Marginal Relevance (MMR) Diversification
 * Balances relevance to seed with diversity among selected recommendations.
 * Prevents 5 songs by the same artist appearing back-to-back.
 */
function rankWithMMR(candidatesWithScores, seedFeatures, limit = 20, lambda = 0.72) {
  const selected = [];
  const remaining = [...candidatesWithScores];
  const artistCounts = new Map();

  while (selected.length < limit && remaining.length > 0) {
    let bestScore = -Infinity;
    let bestIdx = -1;

    for (let i = 0; i < remaining.length; i++) {
      const candidate = remaining[i];
      const relevance = candidate.score;

      // Diversity penalty: maximum similarity with already selected songs
      let maxSimWithSelected = 0;
      for (const sel of selected) {
        const sim = computeSongSimilarity(candidate.features, sel.features);
        if (sim > maxSimWithSelected) {
          maxSimWithSelected = sim;
        }
      }

      // Artist saturation penalty (max 2 songs per artist in top 10)
      const primaryArtist = candidate.features.primaryArtists[0] || "unknown";
      const count = artistCounts.get(primaryArtist) || 0;
      const saturationPenalty = count >= 2 ? 0.35 : (count >= 1 ? 0.12 : 0);

      // MMR Formula: lambda * Relevance - (1 - lambda) * MaxSimilarityToSelected - SaturationPenalty
      const mmrScore = (lambda * relevance) - ((1 - lambda) * maxSimWithSelected) - saturationPenalty;

      if (mmrScore > bestScore) {
        bestScore = mmrScore;
        bestIdx = i;
      }
    }

    if (bestIdx >= 0) {
      const chosen = remaining.splice(bestIdx, 1)[0];
      selected.push(chosen);
      const primaryArtist = chosen.features.primaryArtists[0] || "unknown";
      artistCounts.set(primaryArtist, (artistCounts.get(primaryArtist) || 0) + 1);
    } else {
      break;
    }
  }

  return selected.map(item => item.raw);
}

/**
 * Main Recommendation Entrypoint
 * 
 * @param {Object} seedSongRaw - Current seed song object
 * @param {Object} options - Options containing history, favorites, excludeIds, limit
 * @returns {Promise<Array>} List of recommended song objects
 */
async function getRecommendations(seedSongRaw, options = {}) {
  const limit = options.limit || 20;
  const seedFeatures = extractFeatures(seedSongRaw);
  if (!seedFeatures) return [];

  // Exclude current seed and any passed exclude IDs
  const excludeIds = new Set(options.excludeIds || []);
  excludeIds.add(seedFeatures.id);

  // 1. Candidate Generation
  const candidates = await generateCandidates(seedFeatures, {
    history: options.history,
    favorites: options.favorites,
    excludeIds
  });

  if (candidates.length === 0) {
    return [];
  }

  // 2. Score Candidates against Seed and User Taste Profile
  const scored = candidates.map(cand => {
    let score = computeSongSimilarity(cand.features, seedFeatures) * cand.sourceWeight;

    // User History Affinity Boost (Time decayed)
    if (Array.isArray(options.history) && options.history.length > 0) {
      for (let idx = 0; idx < Math.min(5, options.history.length); idx++) {
        const hFeat = extractFeatures(options.history[idx]);
        if (hFeat) {
          const histSim = computeSongSimilarity(cand.features, hFeat);
          const timeDecay = Math.exp(-idx / 3.0); // most recent weighs more
          score += 0.15 * histSim * timeDecay;
        }
      }
    }

    // User Favorites Boost
    if (Array.isArray(options.favorites) && options.favorites.length > 0) {
      for (const fav of options.favorites.slice(0, 5)) {
        const favFeat = extractFeatures(fav);
        if (favFeat) {
          const favSim = computeSongSimilarity(cand.features, favFeat);
          if (favSim > 0.5) score += 0.10 * favSim;
        }
      }
    }

    return {
      raw: cand.raw,
      features: cand.features,
      score
    };
  });

  // 3. MMR Diversity Re-ranking
  const finalSongs = rankWithMMR(scored, seedFeatures, limit);
  return finalSongs;
}

/**
 * Generate a personalized Discover / Mix station based on user's taste profile
 */
async function getPersonalizedMix(history = [], favorites = [], limit = 20) {
  const excludeIds = new Set();
  const tasteSeeds = [];

  // Collect seeds from top favorites and recent history
  for (const fav of favorites.slice(0, 3)) {
    const feat = extractFeatures(fav);
    if (feat) {
      tasteSeeds.push(feat);
      excludeIds.add(feat.id);
    }
  }

  for (const hist of history.slice(0, 3)) {
    const feat = extractFeatures(hist);
    if (feat && !excludeIds.has(feat.id)) {
      tasteSeeds.push(feat);
      excludeIds.add(feat.id);
    }
  }

  if (tasteSeeds.length === 0) {
    // Fallback to top hits
    const fallback = await fetchJson(`${SAAVN_BASE}/search/songs?query=top%20hits%202026&limit=${limit}`);
    return fallback?.results || (Array.isArray(fallback) ? fallback : []);
  }

  // Aggregate candidate pool across taste seeds
  const candidatesMap = new Map();
  const candidateGroups = await Promise.all(
    tasteSeeds.map((seed) => generateCandidates(seed, { excludeIds }))
  );
  for (const cands of candidateGroups) {
    for (const c of cands) {
      if (!candidatesMap.has(c.features.id)) {
        candidatesMap.set(c.features.id, c);
      }
    }
  }

  const scored = Array.from(candidatesMap.values()).map(cand => {
    let maxSeedScore = 0;
    for (const seed of tasteSeeds) {
      const sim = computeSongSimilarity(cand.features, seed);
      if (sim > maxSeedScore) maxSeedScore = sim;
    }
    return {
      raw: cand.raw,
      features: cand.features,
      score: maxSeedScore
    };
  });

  const representativeSeed = tasteSeeds[0];
  return rankWithMMR(scored, representativeSeed, limit, 0.65);
}

module.exports = {
  getRecommendations,
  getPersonalizedMix,
  computeSongSimilarity,
  extractFeatures
};
