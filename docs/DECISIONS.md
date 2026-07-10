# Decisions

Running log of deliberate fork-level decisions (newest first). Each entry
records enough context to re-evaluate later without re-doing the analysis.

## 2026-07-10 — Do not port upstream's WebSocket stack until a consumer exists

**Context.** The 2026-07-10 upstream merge (`2387c18`) kept this fork's own
`hs.http` / `hs.httpserver` / `hs.menubar` implementations and dropped
upstream's parallel ones (case-colliding filenames; vibecast depends on the
fork's `serve()` / `setSVG()` / `directConnection` API). That left upstream
features unadopted, and we evaluated porting them into the fork's
implementations.

**Findings.**
- Upstream's directory-listing XSS fix and TLS p12 crash fix are
  **inapplicable**: the fork's server has no static/directory serving and no
  TLS.
- The portable remainder is exactly: WebSocket client
  (`hs.http.openWebSocket(url)` returning a builder-callback `HSWebSocket`),
  WebSocket server (`server.setWebSocketCallback(path, (event, conn, msg))`),
  and oversized-frame guards (a property of the WS frame codec).
- **Zero consumers**: nothing in vibecast, ClipPad, or CrossMac uses
  websockets. Live systems run on hs.multipeer, BLE, and the plain-HTTP
  webhook.

**Decision.** Defer the port. An unconsumed parallel WebSocket stack is pure
merge surface with no user. Revisit when a first consumer is named — the two
plausible candidates in this ecosystem are ClipPad live clipboard push and
devbridge streaming (live log/event tail). When that happens, port with the
consumer as the acceptance test, and pull upstream's frame-guard behaviour
(oversized-frame rejection, maxBodySize) into the codec from day one.

**Standing merge rule** (also in the assistant's project memory): future
upstream syncs keep dropping upstream's `hs.http`/`hs.httpserver`/`hs.menubar`
files in favour of the fork's, until this decision is revisited.
