# Hermosa backend

This directory contains two deployment targets:

- **HTTP API**: serverless handlers in `api/`, suitable for Vercel.
- **Room sync service**: the persistent WebSocket server in `index.js`, suitable for Render, Fly.io, Railway, or another long-running Node host.

Vercel Functions cannot keep the in-memory room map or long-lived WebSocket connections alive. Deploying this directory to Vercel provides only the HTTP API; the app's room server URL must point at the separately deployed persistent service. Rooms are currently process-local and disappear when that service restarts. Horizontal scaling requires shared room storage/pub-sub or sticky sessions.

## Local development

```bash
npm install
npm test
npm start
```

`PORT` defaults to `8080`. `SAAVN_API_URL` optionally overrides the upstream JioSaavn-compatible API base URL.

## HTTP API on Vercel

Set the Vercel project's root directory to `server`. Files under `api/` are deployed as independent Node functions. `vercel.json` also rewrites `/health` to `/api/health`.

| Method | Route | Purpose |
| --- | --- | --- |
| `GET` | `/health` or `/api/health` | Readiness check |
| `GET`, `POST` | `/api/recommend` | Recommendations by song ID or seed object |
| `GET`, `POST` | `/api/personalized` | Personalized mix from history/favorites |
| `GET`, `POST` | `/api/lyrics` | Synced/plain lyrics lookup |

Recommendation requests accept `limit` from 1 to 50. Profile arrays and request bodies are bounded, and outbound metadata/lyrics calls time out.

Example:

```json
{
  "seed": { "id": "song-id", "name": "Song" },
  "history": [],
  "favorites": [],
  "excludeIds": [],
  "limit": 20
}
```

## Persistent room service

Deploy `server` as a Node web service with:

- Build: `npm ci`
- Start: `npm start`
- Health check: `/health`
- WebSocket URL: `wss://<host>`

The first member is host. Only the host may send `sync_state` or `sync_position`. When the host leaves, hosting moves to the oldest remaining member and clients receive `host_changed`. The service stores the latest playback state in memory and sends it to later joiners.

Playback state shape:

```json
{
  "song": { "id": "song-id" },
  "queue": [{ "id": "song-id" }],
  "currentIndex": 0,
  "playing": true,
  "positionMs": 1234
}
```
