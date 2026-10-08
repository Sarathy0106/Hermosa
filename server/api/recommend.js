const { getRecommendations } = require("../recommendation_engine.js");
const { allowMethods, boundedArray, boundedLimit, fetchWithTimeout } = require("./http.js");

const SAAVN_BASE = process.env.SAAVN_API_URL || "https://resona-saavn-api.vercel.app/api";

module.exports = async function handler(req, res) {
  if (!allowMethods(req, res, ["GET", "POST"])) return;

  try {
    const url = new URL(req.url, `http://${req.headers.host || "localhost"}`);
    const body = req.body || {};
    const limit = boundedLimit(url.searchParams.get("limit") || body.limit);
    const history = boundedArray(body.history, "history");
    const favorites = boundedArray(body.favorites, "favorites");
    const excludeIds = boundedArray(body.excludeIds, "excludeIds", 500);
    let seedSong = body.seed;
    const songId = url.searchParams.get("id") || url.searchParams.get("songId");

    if (seedSong !== undefined && (!seedSong || typeof seedSong !== "object" || Array.isArray(seedSong))) {
      return res.status(400).json({ success: false, message: "seed must be a song object" });
    }

    if (!seedSong && songId) {
      if (songId.length > 200) return res.status(400).json({ success: false, message: "Invalid song id" });
      const songRes = await fetchWithTimeout(`${SAAVN_BASE}/songs/${encodeURIComponent(songId)}`);
      if (!songRes.ok) return res.status(502).json({ success: false, message: "Song metadata service unavailable" });
      const songJson = await songRes.json();
      if (songJson?.success && Array.isArray(songJson.data) && songJson.data.length > 0) seedSong = songJson.data[0];
    }

    if (!seedSong) {
      return res.status(400).json({
        success: false,
        message: "Missing seed song. Provide 'id' query param or 'seed' in request body.",
      });
    }

    const recommendations = await getRecommendations(seedSong, { history, favorites, excludeIds, limit });
    return res.status(200).json({
      success: true,
      count: recommendations.length,
      seed: { id: seedSong.id, name: seedSong.name || seedSong.title },
      data: recommendations,
    });
  } catch (error) {
    const status = error.statusCode || (error.name === "AbortError" ? 504 : 500);
    if (status >= 500) console.error("[Recommendation API]", error.message);
    return res.status(status).json({
      success: false,
      message: status === 500 ? "Internal server error" : error.message || "Upstream request timed out",
    });
  }
};
