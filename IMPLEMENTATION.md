# Material 3 refresh and synchronization repairs

## Delivered
- Pixel-inspired tonal Material 3 theme, rounded artwork/cards, labeled mobile navigation, responsive desktop navigation/player, and redesigned full-screen player.
- Search handoff, loading/retry/empty states, constrained desktop layouts, and removal of misleading controls.
- Playback async handling, queue revision protection, safer metadata parsing, download error handling, serialized room updates, drift tolerance, initial state, and host migration handling.
- Backend host authority, late-join state replay, membership cleanup, bounded input, upstream timeouts, and separate Vercel HTTP routes.

## Verification
- `flutter analyze`: clean.
- `flutter test`: 5 tests passed.
- `cd server && npm test`: 3 integration tests passed.
- `flutter build web --release`: successful.
- Rendered browser inspection was blocked by a browser-open timeout; visual validation and real-device playback remain outstanding.
- Native Android/iOS builds and two-device audio synchronization have not been verified.

## Deployment status
Deployed on 2026-09-30 after authentication was restored, using `npx --yes vercel@latest` (the installed CLI was too old).

- Frontend: https://hermosa-chi.vercel.app
- HTTP API: https://server-ebon-one-95.vercel.app
- Verified public frontend and Flutter bundle return HTTP 200, API health returns status `ok`, and missing recommendation seed returns HTTP 400.
- Frontend was built locally with the production API origin, copied into `.vercel/output/static`, and deployed with `deploy --prebuilt --prod`. `.vercel/output/config.json` provides static-file serving and SPA fallback.
- Persistent room service was not redeployed. Real-device playback and browser visual checks remain outstanding.

The workspace is already linked to frontend project `hermosa` and backend project `server`.
After authentication, deploy the HTTP backend from `server`, then build Flutter with the returned production API origin:

```sh
cd server
vercel --prod
cd ..
flutter build web --release --dart-define=HERMOSA_API_URL=https://YOUR-API-ORIGIN --dart-define=ROOM_SERVER_URL=wss://YOUR-ROOM-HOST
```

Deploy the generated `build/web` static assets to the linked frontend project. Verify `/api/health`, recommendations, lyrics, web navigation, and playback on the production URLs before declaring deployment complete.

Vercel hosts the web frontend and HTTP API, **not** the persistent WebSocket room service. Deploy updated `server/index.js` to a long-running Node host separately. The existing configured Render URL has not been redeployed by this task. See `server/README.md` for backend details. Native mobile binaries are distributed separately, not hosted as applications on Vercel.
