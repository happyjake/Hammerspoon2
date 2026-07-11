# Calendar MCP security posture

The `calendar-mcp` vibecast feature exposes calendar/reminder CRUD over loopback HTTP to
local Agents. It is adapted from `devbridge`, but its security model deliberately
diverges from `devbridge`'s dev-only defaults because it handles sensitive user data and is
meant to run day-to-day once the user enables it (the feature itself ships disabled by
default).

- **Bind `127.0.0.1` only**, and additionally assert `req.remoteAddress` is loopback.
- **Bearer token is the primary gate.** `Authorization: Bearer <token>` (MCP-conventional
  — not `devbridge`'s `X-Devbridge-Token`), compared constant-time. Mismatch/absent → 401.
- **The token is Keychain-minted**, mirroring `clippad`/`webhook`: HS2 generates a strong
  random token on first enable and stores it in Keychain; it is revealed once so the user
  can wire `HS_MCP_TOKEN` into their shell profile and the herdr launchd plist's
  `EnvironmentVariables`. We do **not** follow `devbridge`'s plaintext-in-config token —
  that is its explicit dev-only exception and a leak vector if the config is ever synced.
- **Origin is belt-and-suspenders, applied leniently.** Reject only when `Origin` is a
  real web origin (`http://`/`https://`) that isn't a loopback host; allow absent or
  non-web Origins. This blocks browser DNS-rebinding while staying robust no matter what a
  non-browser MCP client sends. We reject `devbridge`'s "403 on any Origin present" guard:
  it would silently break a client that sends any Origin, and the bearer token + no-CORS
  already defeat the browser attack it targets.

Rationale: a malicious web page can't read the token and can't set `Authorization`
cross-origin without a CORS preflight we never grant, so the token alone defeats the
browser attack; loopback binding + Keychain storage + lenient Origin are defense-in-depth.

Scope note (not security): the endpoint is reachable only by **local** clients. claude.ai
in the cloud cannot reach `127.0.0.1` (that needs a public HTTPS tunnel + OAuth) — stated
in the feature README.
