const { getPersonalizedMix } = require("../recommendation_engine.js");
const { allowMethods, boundedArray, boundedLimit } = require("./http.js");

module.exports = async function handler(req, res) {
  if (!allowMethods(req, res, ["GET", "POST"])) return;

  try {
    const url = new URL(req.url, `http://${req.headers.host || "localhost"}`);
    const body = req.body || {};
    const limit = boundedLimit(url.searchParams.get("limit") || body.limit);
    const history = boundedArray(body.history, "history");
    const favorites = boundedArray(body.favorites, "favorites");
    const songs = await getPersonalizedMix(history, favorites, limit);
    return res.status(200).json({ success: true, count: songs.length, data: songs });
  } catch (error) {
    const status = error.statusCode || 500;
    if (status >= 500) console.error("[Personalized API]", error.message);
    return res.status(status).json({ success: false, message: status === 500 ? "Internal server error" : error.message });
  }
};
