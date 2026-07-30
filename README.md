# Hermosa

A beautiful Flutter music streaming player with listen‑together rooms.

## Room Server (Listen Together)

The room feature lets people sync playback in real time. It needs a tiny WebSocket server.

### Deploy (free options)

**Render** (recommended — 750 hours/month free):
1. Fork/push this repo to GitHub
2. Go to [render.com](https://render.com) → New → Web Service
3. Connect your repo, set **Root Directory** to `server`, **Start Command** to `npm start`
4. Deploy — you get a `wss://your-app.onrender.com` URL

**Railway** (US$5 credit, no card needed):
1. `railway up` from the `server/` directory
2. Set start command: `node index.js`

**Fly.io**:
```
cd server
fly launch
fly deploy
```

**or run locally**:
```bash
cd server
npm install
npm start
# → ws://localhost:8080
```

### Connect in the app

Tap **Room** on the player screen, paste your server URL (`wss://…` or `ws://…`), then **Create Room** or **Join** with a 6‑character code.

### How it works

- The host's current song, queue, and playback position are synced to all members every 3 seconds
- When the host skips/pauses, the change broadcasts immediately
- Rooms are held in memory; they disappear when the last person leaves
