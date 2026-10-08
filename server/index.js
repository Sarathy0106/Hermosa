const http = require("http");
const crypto = require("crypto");
const { WebSocket, WebSocketServer } = require("ws");
const recommendHandler = require("./api/recommend.js");
const personalizedHandler = require("./api/personalized.js");
const lyricsHandler = require("./api/lyrics.js");
const healthHandler = require("./api/health.js");
const { readJsonBody, sendNodeJson, toVercelRequest, toVercelResponse } = require("./api/http.js");

const PORT = Number(process.env.PORT) || 8080;
const ROOM_CODE_PATTERN = /^[A-HJ-NP-Z2-9]{6}$/;
const MAX_QUEUE_LENGTH = 500;
const MAX_POSITION_MS = 24 * 60 * 60 * 1000;

function isObject(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function createRoomStore() {
  return new Map();
}

function randomCode(rooms) {
  const chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
  let code;
  do {
    code = "";
    for (let i = 0; i < 6; i += 1) code += chars[(Math.random() * chars.length) | 0];
  } while (rooms.has(code));
  return code;
}

function memberList(room) {
  return [...room.members.keys()].map((id) => ({ id }));
}

function send(ws, message) {
  if (ws.readyState === WebSocket.OPEN) ws.send(JSON.stringify(message));
}

function broadcast(room, senderId, message) {
  for (const [id, socket] of room.members) {
    if (id !== senderId) send(socket, message);
  }
}

function validateState(state) {
  if (!isObject(state)) return null;
  const { song, queue, currentIndex, playing, positionMs } = state;
  if (song !== null && !isObject(song)) return null;
  if (!Array.isArray(queue) || queue.length > MAX_QUEUE_LENGTH || queue.some((item) => !isObject(item))) return null;
  if (!Number.isInteger(currentIndex) || currentIndex < 0 || (queue.length === 0 ? currentIndex !== 0 : currentIndex >= queue.length)) return null;
  if (typeof playing !== "boolean") return null;
  if (!Number.isFinite(positionMs) || positionMs < 0 || positionMs > MAX_POSITION_MS) return null;
  return { song, queue, currentIndex, playing, positionMs: Math.round(positionMs) };
}

function validatePosition(message) {
  if (!Number.isFinite(message.positionMs) || message.positionMs < 0 || message.positionMs > MAX_POSITION_MS) return null;
  if (typeof message.playing !== "boolean") return null;
  return { positionMs: Math.round(message.positionMs), playing: message.playing };
}

function attachRoomServer(server, rooms = createRoomStore()) {
  const wss = new WebSocketServer({ server, maxPayload: 256 * 1024 });

  wss.on("connection", (ws) => {
    let membership = null;

    function error(message) {
      send(ws, { type: "error", message });
    }

    function leaveRoom({ acknowledge = false } = {}) {
      if (!membership) {
        if (acknowledge) send(ws, { type: "room_left" });
        return;
      }

      const { code, memberId } = membership;
      const room = rooms.get(code);
      membership = null;
      if (!room || room.members.get(memberId) !== ws) {
        if (acknowledge) send(ws, { type: "room_left" });
        return;
      }

      const wasHost = room.hostId === memberId;
      room.members.delete(memberId);
      if (room.members.size === 0) {
        rooms.delete(code);
      } else {
        if (wasHost) room.hostId = room.members.keys().next().value;
        const members = memberList(room);
        broadcast(room, memberId, { type: "member_left", memberId, members, hostId: room.hostId });
        if (wasHost) broadcast(room, memberId, { type: "host_changed", hostId: room.hostId, members });
      }
      if (acknowledge) send(ws, { type: "room_left" });
    }

    ws.on("message", (raw, isBinary) => {
      if (isBinary) return error("Binary messages are not supported");
      let message;
      try {
        message = JSON.parse(raw.toString());
      } catch {
        return error("Message must be valid JSON");
      }
      if (!isObject(message) || typeof message.type !== "string") return error("Message type is required");

      switch (message.type) {
        case "create_room": {
          leaveRoom();
          const code = randomCode(rooms);
          const memberId = crypto.randomUUID();
          const room = {
            code,
            hostId: memberId,
            members: new Map([[memberId, ws]]),
            state: null,
          };
          rooms.set(code, room);
          membership = { code, memberId };
          send(ws, { type: "room_created", code, memberId, members: memberList(room), hostId: room.hostId });
          return;
        }

        case "join_room": {
          const code = typeof message.code === "string" ? message.code.trim().toUpperCase() : "";
          if (!ROOM_CODE_PATTERN.test(code)) return error("Invalid room code");
          const room = rooms.get(code);
          if (!room) return error("Room not found");

          if (membership?.code === code && room.members.get(membership.memberId) === ws) {
            send(ws, {
              type: "room_joined",
              code,
              memberId: membership.memberId,
              members: memberList(room),
              hostId: room.hostId,
            });
            if (room.state) {
              send(ws, { type: "state_update", state: room.state });
              send(ws, {
                type: "position_update",
                positionMs: room.state.positionMs,
                playing: room.state.playing,
              });
            }
            return;
          }

          leaveRoom();
          const memberId = crypto.randomUUID();
          room.members.set(memberId, ws);
          membership = { code, memberId };
          const members = memberList(room);
          send(ws, { type: "room_joined", code, memberId, members, hostId: room.hostId });
          if (room.state) {
            send(ws, { type: "state_update", state: room.state });
            send(ws, {
              type: "position_update",
              positionMs: room.state.positionMs,
              playing: room.state.playing,
            });
          }
          broadcast(room, memberId, { type: "member_joined", memberId, members, hostId: room.hostId });
          return;
        }

        case "leave_room":
          leaveRoom({ acknowledge: true });
          return;

        case "sync_state": {
          if (!membership) return error("Join a room before syncing");
          const room = rooms.get(membership.code);
          if (!room || room.members.get(membership.memberId) !== ws) return error("Room membership expired");
          if (room.hostId !== membership.memberId) return error("Only the host can sync playback");
          const state = validateState(message.state);
          if (!state) return error("Invalid playback state");
          room.state = state;
          broadcast(room, membership.memberId, { type: "state_update", state });
          return;
        }

        case "sync_position": {
          if (!membership) return error("Join a room before syncing");
          const room = rooms.get(membership.code);
          if (!room || room.members.get(membership.memberId) !== ws) return error("Room membership expired");
          if (room.hostId !== membership.memberId) return error("Only the host can sync playback");
          const position = validatePosition(message);
          if (!position) return error("Invalid playback position");
          if (room.state) room.state = { ...room.state, ...position };
          broadcast(room, membership.memberId, { type: "position_update", ...position });
          return;
        }

        default:
          error("Unsupported message type");
      }
    });

    ws.on("close", () => leaveRoom());
    ws.on("error", () => leaveRoom());
  });

  return wss;
}

function createHttpServer({ rooms = createRoomStore() } = {}) {
  const routes = new Map([
    ["/api/recommend", recommendHandler],
    ["/api/radio", recommendHandler],
    ["/api/personalized", personalizedHandler],
    ["/api/lyrics", lyricsHandler],
    ["/health", healthHandler],
    ["/", healthHandler],
  ]);

  const server = http.createServer(async (req, res) => {
    try {
      const url = new URL(req.url, `http://${req.headers.host || "localhost"}`);
      const handler = routes.get(url.pathname);
      if (!handler) return sendNodeJson(res, 404, { success: false, message: "Route not found" });
      const body = req.method === "POST" ? await readJsonBody(req) : undefined;
      return await handler(toVercelRequest(req, body), toVercelResponse(res), { activeRooms: rooms.size });
    } catch (error) {
      const status = error.statusCode || 500;
      return sendNodeJson(res, status, { success: false, message: status === 500 ? "Internal server error" : error.message });
    }
  });
  attachRoomServer(server, rooms);
  return { server, rooms };
}

if (require.main === module) {
  const { server } = createHttpServer();
  server.listen(PORT, () => console.log(`Hermosa API and room server listening on port ${PORT}`));
}

module.exports = { attachRoomServer, createHttpServer, createRoomStore, validatePosition, validateState };
