import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models.dart';
import 'saavn_api.dart';

class _SongFeatures {
  final String id;
  final String title;
  final String language;
  final int year;
  final int playCount;
  final List<String> primaryArtists;
  final List<String> allArtists;
  final String albumId;
  final Song song;

  _SongFeatures({
    required this.id,
    required this.title,
    required this.language,
    required this.year,
    required this.playCount,
    required this.primaryArtists,
    required this.allArtists,
    required this.albumId,
    required this.song,
  });

  static _SongFeatures fromSong(Song s) {
    final raw = s.raw;
    final lang = (raw['language'] ?? 'unknown').toString().toLowerCase();
    final yearValue = raw['year'];
    final yr = yearValue is num
        ? yearValue.toInt()
        : int.tryParse(yearValue?.toString() ?? '') ?? 0;
    final playCountValue = raw['playCount'];
    final pc = playCountValue is num
        ? playCountValue.toInt()
        : int.tryParse(playCountValue?.toString() ?? '') ?? 0;

    final primary = <String>[];
    final all = <String>[];

    final artistsObj = raw['artists'];
    if (artistsObj is Map) {
      final pList = artistsObj['primary'];
      if (pList is List) {
        for (final a in pList) {
          if (a is Map && a['name'] != null) {
            primary.add((a['name'] as String).toLowerCase().trim());
          }
        }
      }
      final aList = artistsObj['all'];
      if (aList is List) {
        for (final a in aList) {
          if (a is Map && a['name'] != null) {
            all.add((a['name'] as String).toLowerCase().trim());
          }
        }
      }
    }

    if (primary.isEmpty) {
      final names = s.artists
          .split(',')
          .map((e) => e.toLowerCase().trim())
          .where((e) => e.isNotEmpty);
      primary.addAll(names);
      all.addAll(names);
    }

    return _SongFeatures(
      id: s.id,
      title: s.title.trim(),
      language: lang,
      year: yr,
      playCount: pc,
      primaryArtists: primary,
      allArtists: all,
      albumId: s.albumId ?? '',
      song: s,
    );
  }
}

class RecommendationService extends ChangeNotifier {
  static final defaultEndpoint = SaavnApi.httpApiUri(
    '/api/recommend',
  ).toString();

  final SaavnApi _api;
  final http.Client _client = http.Client();
  String _endpoint = defaultEndpoint;

  RecommendationService(this._api);

  String get endpoint => _endpoint;

  void setCustomEndpoint(String? url) {
    _endpoint = url ?? defaultEndpoint;
    notifyListeners();
  }

  /// Calculates content-based similarity score [0.0 - 1.0]
  double _computeSimilarity(_SongFeatures cand, _SongFeatures seed) {
    if (cand.id == seed.id) return 1.0;
    double score = 0.0;

    // 1. Language Match (Weight: 0.35)
    if (cand.language.isNotEmpty &&
        seed.language.isNotEmpty &&
        cand.language == seed.language) {
      score += 0.35;
    } else if (cand.language == 'english' || seed.language == 'english') {
      score += 0.05;
    }

    // 2. Artist Overlap (Weight: 0.35)
    final seedPrimary = seed.primaryArtists.toSet();
    final candPrimary = cand.primaryArtists.toSet();
    final primaryIntersect = candPrimary.intersection(seedPrimary).length;

    if (primaryIntersect > 0) {
      score +=
          0.35 *
          math.min(1.0, primaryIntersect / math.max(1, seedPrimary.length));
    } else {
      final seedAll = seed.allArtists.toSet();
      final candAll = cand.allArtists.toSet();
      final allIntersect = candAll.intersection(seedAll).length;
      if (allIntersect > 0) {
        score +=
            0.20 * math.min(1.0, allIntersect / math.max(1, seedAll.length));
      }
    }

    // 3. Era / Year Proximity with Exponential Decay (Weight: 0.15)
    if (cand.year > 0 && seed.year > 0) {
      final diff = (cand.year - seed.year).abs();
      final eraScore = math.exp(-diff / 7.0);
      score += 0.15 * eraScore;
    } else {
      score += 0.07;
    }

    // 4. Album Match (Weight: 0.05)
    if (cand.albumId.isNotEmpty &&
        seed.albumId.isNotEmpty &&
        cand.albumId == seed.albumId) {
      score += 0.05;
    }

    // 5. Popularity Signal (Weight: 0.10)
    if (cand.playCount > 0) {
      final logPlay = math.log(math.max(100, cand.playCount)) / math.ln10;
      final normPop = math.min(1.0, math.max(0.0, (logPlay - 3.0) / 5.0));
      score += 0.10 * normPop;
    } else {
      score += 0.05;
    }

    return math.min(1.0, score);
  }

  /// Maximal Marginal Relevance (MMR) Diversification
  List<Song> _rankWithMMR(
    List<(_SongFeatures, double)> candidates,
    _SongFeatures seed,
    int limit, {
    double lambda = 0.72,
  }) {
    final selected = <_SongFeatures>[];
    final remaining = List<(_SongFeatures, double)>.from(candidates);
    final artistCounts = <String, int>{};

    while (selected.length < limit && remaining.isNotEmpty) {
      double bestScore = -double.infinity;
      int bestIdx = -1;

      for (var i = 0; i < remaining.length; i++) {
        final (cand, relevance) = remaining[i];

        // Max similarity to already selected
        double maxSim = 0.0;
        for (final sel in selected) {
          final sim = _computeSimilarity(cand, sel);
          if (sim > maxSim) maxSim = sim;
        }

        // Artist saturation penalty
        final mainArtist = cand.primaryArtists.isNotEmpty
            ? cand.primaryArtists.first
            : 'unknown';
        final count = artistCounts[mainArtist] ?? 0;
        final penalty = count >= 2 ? 0.35 : (count >= 1 ? 0.12 : 0.0);

        final mmrScore =
            (lambda * relevance) - ((1.0 - lambda) * maxSim) - penalty;

        if (mmrScore > bestScore) {
          bestScore = mmrScore;
          bestIdx = i;
        }
      }

      if (bestIdx >= 0) {
        final (chosen, _) = remaining.removeAt(bestIdx);
        selected.add(chosen);
        final mainArtist = chosen.primaryArtists.isNotEmpty
            ? chosen.primaryArtists.first
            : 'unknown';
        artistCounts[mainArtist] = (artistCounts[mainArtist] ?? 0) + 1;
      } else {
        break;
      }
    }

    return selected.map((e) => e.song).toList();
  }

  /// Fetch candidate songs from multi-hop sources
  Future<List<Song>> _fetchCandidates(
    _SongFeatures seed, {
    List<Song>? history,
    List<Song>? favorites,
    Set<String>? excludeIds,
  }) async {
    final candidatesMap = <String, Song>{};
    final excluded = excludeIds ?? <String>{};
    excluded.add(seed.id);

    void addSongs(List<Song> songs) {
      for (final s in songs) {
        if (!s.playable || excluded.contains(s.id)) continue;
        candidatesMap[s.id] = s;
      }
    }

    final futures = <Future<void>>[];

    // Source 1: Direct JioSaavn suggestions
    futures.add(
      _api.songSuggestions(seed.id).then(addSongs).catchError((_) {}),
    );

    // Source 2: Primary artist hits
    if (seed.primaryArtists.isNotEmpty) {
      futures.add(
        _api
            .searchSongs(seed.primaryArtists.first, limit: 15)
            .then(addSongs)
            .catchError((_) {}),
      );
    }

    // Source 3: Language trending cluster
    if (seed.language.isNotEmpty) {
      final queries = [
        '${seed.language} hits',
        '${seed.language} trending',
        '${seed.language} top songs',
      ];
      final query = queries[math.Random().nextInt(queries.length)];
      futures.add(
        _api.searchSongs(query, limit: 15).then(addSongs).catchError((_) {}),
      );
    }

    // Source 4: User recent history suggestions
    if (history != null && history.isNotEmpty) {
      for (final hSong in history.take(2)) {
        if (hSong.id != seed.id) {
          futures.add(
            _api.songSuggestions(hSong.id).then(addSongs).catchError((_) {}),
          );
        }
      }
    }

    // Source 5: User favorites suggestions
    if (favorites != null && favorites.isNotEmpty) {
      final randomFav = favorites[math.Random().nextInt(favorites.length)];
      if (randomFav.id != seed.id) {
        futures.add(
          _api.songSuggestions(randomFav.id).then(addSongs).catchError((_) {}),
        );
      }
    }

    await Future.wait(futures);
    return candidatesMap.values.toList();
  }

  /// Get recommendations for a seed song using hybrid multi-factor algorithm
  Future<List<Song>> getRecommendations(
    Song seedSong, {
    List<Song>? history,
    List<Song>? favorites,
    List<String>? excludeIds,
    int limit = 15,
  }) async {
    // Attempt remote Vercel/Render microservice if endpoint configured
    if (_endpoint.isNotEmpty) {
      try {
        final res = await _client
            .post(
              Uri.parse(_endpoint),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'seed': seedSong.raw,
                'history': (history ?? []).map((s) => s.raw).toList(),
                'favorites': (favorites ?? []).map((s) => s.raw).toList(),
                'excludeIds': excludeIds ?? [],
                'limit': limit,
              }),
            )
            .timeout(const Duration(seconds: 4));

        if (res.statusCode == 200) {
          final json = jsonDecode(res.body) as Map<String, dynamic>;
          if (json['success'] == true && json['data'] is List) {
            final list = (json['data'] as List)
                .map((j) => Song.fromJson((j as Map).cast<String, dynamic>()))
                .where((s) => s.playable)
                .toList();
            if (list.isNotEmpty) return list;
          }
        }
      } catch (_) {
        // Fallback to local high-performance algorithm
      }
    }

    // Local recommendation algorithm
    final seedFeatures = _SongFeatures.fromSong(seedSong);
    final candidates = await _fetchCandidates(
      seedFeatures,
      history: history,
      favorites: favorites,
      excludeIds: (excludeIds ?? []).toSet(),
    );

    if (candidates.isEmpty) return const [];

    final scored = <(_SongFeatures, double)>[];
    for (final cand in candidates) {
      final cFeat = _SongFeatures.fromSong(cand);
      double score = _computeSimilarity(cFeat, seedFeatures);

      // Boost with user history
      if (history != null && history.isNotEmpty) {
        for (var i = 0; i < math.min(4, history.length); i++) {
          final hFeat = _SongFeatures.fromSong(history[i]);
          final sim = _computeSimilarity(cFeat, hFeat);
          final decay = math.exp(-i / 3.0);
          score += 0.15 * sim * decay;
        }
      }

      // Boost with favorites
      if (favorites != null && favorites.isNotEmpty) {
        for (final fav in favorites.take(4)) {
          final fFeat = _SongFeatures.fromSong(fav);
          final sim = _computeSimilarity(cFeat, fFeat);
          if (sim > 0.5) score += 0.10 * sim;
        }
      }

      scored.add((cFeat, score));
    }

    return _rankWithMMR(scored, seedFeatures, limit);
  }

  /// Start a smart infinite radio station seeded by a song
  Future<List<Song>> getSongRadio(Song seedSong, {int limit = 25}) async {
    final recs = await getRecommendations(seedSong, limit: limit - 1);
    return [seedSong, ...recs];
  }

  /// Personalized "Made for You" discovery shelf based on taste profile
  Future<List<Song>> getPersonalizedMix({
    List<Song>? history,
    List<Song>? favorites,
    int limit = 15,
  }) async {
    final tasteSeeds = <Song>[];
    if (favorites != null && favorites.isNotEmpty) {
      tasteSeeds.addAll(favorites.take(3));
    }
    if (history != null && history.isNotEmpty) {
      tasteSeeds.addAll(history.take(3));
    }

    if (tasteSeeds.isEmpty) {
      return _api.searchSongs('top hits 2026', limit: limit);
    }

    final candidateMap = <String, Song>{};
    final excludeIds = tasteSeeds.map((s) => s.id).toSet();

    for (final seed in tasteSeeds) {
      final recs = await getRecommendations(
        seed,
        history: history,
        favorites: favorites,
        excludeIds: excludeIds.toList(),
        limit: 8,
      );
      for (final s in recs) {
        if (!excludeIds.contains(s.id)) {
          candidateMap[s.id] = s;
        }
      }
    }

    final list = candidateMap.values.toList();
    list.shuffle(math.Random());
    return list.take(limit).toList();
  }

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }
}
