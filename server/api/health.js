const { allowMethods } = require("./http.js");

module.exports = function handler(req, res, context = {}) {
  if (!allowMethods(req, res, ["GET"])) return;
  return res.status(200).json({
    status: "ok",
    service: "Hermosa HTTP API",
    version: "1.0.0",
    ...(Number.isInteger(context.activeRooms) ? { activeRooms: context.activeRooms } : {}),
    timestamp: new Date().toISOString(),
  });
};
