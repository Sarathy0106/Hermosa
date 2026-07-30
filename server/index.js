const { WebSocketServer } = require("ws");

const PORT = process.env.PORT || 8080;

const wss = new WebSocketServer({ port: PORT });

// ── In-memory room store ──────────────────────────────────────────────
const rooms = new Map(); // code -> { members: Map<id, ws> }

function randomCode() {
  const chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"; // no I/O/0/1
  let code;
  do {
    code = "";
    for (let i = 0; i < 6; i++) code += chars[Math.random() * chars.length | 0];
  } while (rooms.has(code));
  return code;
}

function broadcast(room, senderId, message) {
  const raw = JSON.stringify(message);
  for (const [id, ws] of room.members) {
    if (id !== senderId && ws.readyState === ws.OPEN) {
      ws.send(raw);
    }
  }
}

function memberList(room) {
  return [...room.members.keys()].map((id) => ({ id }));
}

// ── Connection handling ────────────────────────────────────────────────
wss.on("connection", (ws) => {
  let memberId = "";
  let currentRoom = null;

  ws.on("message", (raw) => {
    let msg;
    try {
      msg = JSON.parse(raw.toString());
    } catch {
      return;
    }

    switch (msg.type) {
      // ── Create room ──────────────────────────────────────────────
      case "create_room": {
        memberId = crypto.randomUUID();
        const code = randomCode();
        const room = { members: new Map([[memberId, ws]]) };
        rooms.set(code, room);
        currentRoom = room;
        ws.send(JSON.stringify({ type: "room_created", code, memberId }));
        break;
      }

      // ── Join room ────────────────────────────────────────────────
      case "join_room": {
        const room = rooms.get(msg.code);
        if (!room) {
          ws.send(JSON.stringify({ type: "error", message: "Room not found" }));
          return;
        }
        memberId = crypto.randomUUID();
        room.members.set(memberId, ws);
        currentRoom = room;

        // Tell the joiner about the room + existing members
        ws.send(
          JSON.stringify({
            type: "room_joined",
            code: msg.code,
            memberId,
            members: memberList(room),
          })
        );

        // Tell everyone else a new member arrived
        broadcast(room, memberId, {
          type: "member_joined",
          memberId,
          members: memberList(room),
        });
        break;
      }

      // ── Leave room ───────────────────────────────────────────────
      case "leave_room": {
        if (currentRoom) {
          currentRoom.members.delete(memberId);
          if (currentRoom.members.size === 0) {
            // Last member left → destroy room
            for (const [code, r] of rooms) {
              if (r === currentRoom) rooms.delete(code);
            }
          } else {
            broadcast(currentRoom, memberId, {
              type: "member_left",
              memberId,
              members: memberList(currentRoom),
            });
          }
          currentRoom = null;
        }
        ws.send(JSON.stringify({ type: "room_left" }));
        break;
      }

      // ── Host sync: playback state change ─────────────────────────
      case "sync_state": {
        if (currentRoom) {
          broadcast(currentRoom, memberId, {
            type: "state_update",
            state: msg.state,
          });
        }
        break;
      }

      // ── Sync position (seek / periodic tick) ─────────────────────
      case "sync_position": {
        if (currentRoom) {
          broadcast(currentRoom, memberId, {
            type: "position_update",
            positionMs: msg.positionMs,
            playing: msg.playing,
          });
        }
        break;
      }
    }
  });

  ws.on("close", () => {
    if (currentRoom) {
      currentRoom.members.delete(memberId);
      if (currentRoom.members.size === 0) {
        for (const [code, r] of rooms) {
          if (r === currentRoom) rooms.delete(code);
        }
      } else {
        broadcast(currentRoom, memberId, {
          type: "member_left",
          memberId,
          members: memberList(currentRoom),
        });
      }
    }
  });
});

console.log(`Hermosa room server running on port ${PORT}`);
