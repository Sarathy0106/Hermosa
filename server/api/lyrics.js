const { allowMethods, fetchWithTimeout } = require("./http.js");

const SAAVN_BASE = process.env.SAAVN_API_URL || "https://resona-saavn-api.vercel.app/api";
const LRCLIB_BASE = "https://lrclib.net/api";

function cleanTitle(title) {
  return title.replace(/\(.*?\)/g, "").replace(/\[.*?\]/g, "").replace(/- .*$/, "").trim();
}

function cleanArtist(artist) {
  return artist.split(",")[0].trim();
}

function boundedString(value, name, maximum = 300) {
  if (value === undefined || value === null || value === "") return "";
  if (typeof value !== "string" || value.length > maximum) {
    const error = new Error(`${name} must be a string with at most ${maximum} characters`);
    error.statusCode = 400;
    throw error;
  }
  return value.trim();
}

async function tryJson(url, headers) {
  try {
    const response = await fetchWithTimeout(url, { headers });
    if (!response.ok) return null;
    return await response.json();
  } catch (error) {
    if (error.name === "AbortError") console.warn(`[Lyrics API] Request timed out: ${new URL(url).origin}`);
    return null;
  }
}

module.exports = async function handler(req, res) {
  if (!allowMethods(req, res, ["GET", "POST"])) return;

  try {
    const url = new URL(req.url, `http://${req.headers.host || "localhost"}`);
    const body = req.body || {};
    let title = boundedString(url.searchParams.get("title") || body.title, "title");
    let artist = boundedString(url.searchParams.get("artist") || body.artist, "artist");
    let duration = url.searchParams.get("duration") || body.duration;
    const id = boundedString(url.searchParams.get("id") || body.id, "id", 200);

    if (duration !== undefined && duration !== null && duration !== "") {
      duration = Number(duration);
      if (!Number.isFinite(duration) || duration < 0 || duration > 24 * 60 * 60) {
        return res.status(400).json({ success: false, message: "duration must be valid seconds", lyrics: null });
      }
      duration = Math.round(duration);
    } else {
      duration = null;
    }

    if ((!title || !artist) && id) {
      const songJson = await tryJson(`${SAAVN_BASE}/songs/${encodeURIComponent(id)}`);
      const song = songJson?.success && Array.isArray(songJson.data) ? songJson.data[0] : null;
      if (song) {
        title ||= song.name || "";
        artist ||= (song.artists?.primary || []).map((item) => item.name).filter(Boolean).join(", ");
        duration ||= Number(song.duration) || null;
      }
    }

    if (!title) {
      return res.status(400).json({ success: false, message: "Missing title or resolvable song id", lyrics: null });
    }

    const cleanedTitle = cleanTitle(title) || title;
    const cleanedArtist = cleanArtist(artist);
    const headers = { "User-Agent": "HermosaApp/1.0.0 (https://github.com/)" };
    const exact = new URL(`${LRCLIB_BASE}/get`);
    exact.searchParams.set("track_name", cleanedTitle);
    if (cleanedArtist) exact.searchParams.set("artist_name", cleanedArtist);
    if (duration !== null) exact.searchParams.set("duration", String(duration));
    let lyrics = await tryJson(exact.toString(), headers);

    if (!lyrics?.syncedLyrics) {
      const searches = [];
      const byFields = new URL(`${LRCLIB_BASE}/search`);
      byFields.searchParams.set("track_name", cleanedTitle);
      if (cleanedArtist) byFields.searchParams.set("artist_name", cleanedArtist);
      searches.push(byFields.toString());
      const broad = new URL(`${LRCLIB_BASE}/search`);
      broad.searchParams.set("q", `${cleanedTitle} ${cleanedArtist}`.trim());
      searches.push(broad.toString());

      for (const searchUrl of searches) {
        const list = await tryJson(searchUrl, headers);
        if (!Array.isArray(list) || list.length === 0) continue;
        const synced = list.find((item) => typeof item.syncedLyrics === "string" && item.syncedLyrics.trim());
        lyrics = synced || lyrics || list.find((item) => item.plainLyrics) || null;
        if (synced) break;
      }
    }

    if (lyrics && (lyrics.syncedLyrics || lyrics.plainLyrics)) {
      const isSynced = Boolean(lyrics.syncedLyrics?.trim());
      return res.status(200).json({
        success: true,
        lyrics: lyrics.syncedLyrics || lyrics.plainLyrics,
        syncedLyrics: lyrics.syncedLyrics || null,
        plainLyrics: lyrics.plainLyrics || null,
        isSynced,
        source: "lrclib",
      });
    }

    return res.status(200).json({ success: false, message: "No lyrics found for this track", lyrics: null });
  } catch (error) {
    const status = error.statusCode || 500;
    if (status >= 500) console.error("[Lyrics API]", error.message);
    return res.status(status).json({
      success: false,
      message: status === 500 ? "Failed to fetch lyrics" : error.message,
      lyrics: null,
    });
  }
};
