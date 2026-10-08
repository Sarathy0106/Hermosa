const assert = require("node:assert/strict");
const { after, before, test } = require("node:test");
const { once } = require("node:events");
const { WebSocket } = require("ws");
const { createHttpServer } = require("../index.js");

let server;
let baseUrl;
let wsUrl;
const sockets = new Set();

before(async () => {
  ({ server } = createHttpServer());
  server.listen(0, "127.0.0.1");
  await once(server, "listening");
  const { port } = server.address();
  baseUrl = `http://127.0.0.1:${port}`;
  wsUrl = `ws://127.0.0.1:${port}`;
});

after(async () => {
  for (const socket of sockets) socket.close();
  server.close();
  await once(server, "close");
});

async function connect() {
  const socket = new WebSocket(wsUrl);
  sockets.add(socket);
  await once(socket, "open");
  const queued = [];
  const waiters = [];
  socket.on("message", (raw) => {
    const message = JSON.parse(raw.toString());
    const index = waiters.findIndex((waiter) => !waiter.type || waiter.type === message.type);
    if (index >= 0) {
      const [waiter] = waiters.splice(index, 1);
      clearTimeout(waiter.timer);
      waiter.resolve(message);
    } else {
      queued.push(message);
    }
  });
  return {
    socket,
    send(message) {
      socket.send(JSON.stringify(message));
    },
    next(type) {
      const index = queued.findIndex((message) => !type || message.type === type);
      if (index >= 0) return Promise.resolve(queued.splice(index, 1)[0]);
      return new Promise((resolve, reject) => {
        const waiter = { type, resolve };
        waiter.timer = setTimeout(() => {
          const waiterIndex = waiters.indexOf(waiter);
          if (waiterIndex >= 0) waiters.splice(waiterIndex, 1);
          reject(new Error(`Timed out waiting for ${type || "message"}`));
        }, 1500);
        waiters.push(waiter);
      });
    },
  };
}

function playbackState(positionMs = 1200) {
  return {
    song: { id: "song-1", name: "One" },
    queue: [{ id: "song-1", name: "One" }, { id: "song-2", name: "Two" }],
    currentIndex: 0,
    playing: true,
    positionMs,
  };
}

test("rooms enforce the host and replay the latest state to joiners", async () => {
  const host = await connect();
  host.send({ type: "create_room" });
  const created = await host.next("room_created");
  assert.equal(created.members.length, 1);
  assert.equal(created.hostId, created.memberId);

  host.send({ type: "sync_state", state: playbackState() });
  host.send({ type: "sync_position", positionMs: 4321, playing: false });

  const guest = await connect();
  guest.send({ type: "join_room", code: created.code.toLowerCase() });
  const joined = await guest.next("room_joined");
  assert.equal(joined.members.length, 2);
  assert.equal(joined.hostId, created.memberId);
  assert.deepEqual((await guest.next("state_update")).state, {
    ...playbackState(4321),
    playing: false,
  });
  assert.deepEqual(await guest.next("position_update"), {
    type: "position_update",
    positionMs: 4321,
    playing: false,
  });

  guest.send({ type: "sync_position", positionMs: 999, playing: true });
  assert.match((await guest.next("error")).message, /Only the host/);

  guest.send({ type: "join_room", code: created.code });
  const repeated = await guest.next("room_joined");
  assert.equal(repeated.memberId, joined.memberId);
  assert.equal(repeated.members.length, 2);

  const peer = await connect();
  peer.send({ type: "join_room", code: created.code });
  await peer.next("room_joined");
  await peer.next("state_update");
  await peer.next("position_update");
  host.socket.close();
  const left = await guest.next("member_left");
  assert.equal(left.members.length, 2);
  assert.equal(left.hostId, joined.memberId);
  assert.equal((await guest.next("host_changed")).hostId, joined.memberId);

  guest.send({ type: "sync_state", state: playbackState(5000) });
  assert.deepEqual((await peer.next("state_update")).state, playbackState(5000));
  guest.socket.close();
  peer.socket.close();
});

test("rooms reject malformed messages and clean up membership when switching rooms", async () => {
  const client = await connect();
  client.socket.send("not-json");
  assert.match((await client.next("error")).message, /valid JSON/);
  client.send({ type: "join_room", code: "bad" });
  assert.match((await client.next("error")).message, /Invalid room code/);
  client.send({ type: "create_room" });
  const first = await client.next("room_created");
  client.send({ type: "sync_state", state: { playing: true } });
  assert.match((await client.next("error")).message, /Invalid playback state/);
  client.send({ type: "create_room" });
  const second = await client.next("room_created");
  assert.notEqual(first.code, second.code);

  const observer = await connect();
  observer.send({ type: "join_room", code: first.code });
  assert.match((await observer.next("error")).message, /Room not found/);
  client.socket.close();
  observer.socket.close();
});

test("HTTP routes are distinct and validate methods and bounded input", async () => {
  const originalFetch = global.fetch;
  global.fetch = async (url, options) => {
    if (String(url).startsWith(baseUrl)) return originalFetch(url, options);
    return {
      ok: true,
      async json() {
        return { success: true, data: { results: [] } };
      },
    };
  };
  try {
    const health = await fetch(`${baseUrl}/health`);
    assert.equal(health.status, 200);
    assert.equal((await health.json()).status, "ok");

    const personalized = await fetch(`${baseUrl}/api/personalized`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ history: [], favorites: [], limit: 5 }),
    });
    assert.equal(personalized.status, 200);
    assert.deepEqual(await personalized.json(), { success: true, count: 0, data: [] });

    const invalidLimit = await fetch(`${baseUrl}/api/recommend?limit=500`);
    assert.equal(invalidLimit.status, 400);
    assert.match((await invalidLimit.json()).message, /limit/);

    const missingLyrics = await fetch(`${baseUrl}/api/lyrics`);
    assert.equal(missingLyrics.status, 400);

    const wrongMethod = await fetch(`${baseUrl}/api/recommend`, { method: "PUT" });
    assert.equal(wrongMethod.status, 405);
    assert.match(wrongMethod.headers.get("allow"), /GET/);

    assert.equal((await fetch(`${baseUrl}/api/does-not-exist`)).status, 404);
  } finally {
    global.fetch = originalFetch;
  }
});
