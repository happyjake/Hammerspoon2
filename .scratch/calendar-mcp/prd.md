---
title: hs.calendar + hs.reminders modules & Calendar MCP permission proxy
status: ready-for-agent
category: enhancement
labels: [enhancement, ready-for-agent]
created: 2026-07-11
tracker: local-markdown
related-docs:
  - CONTEXT.md (glossary: Event, Occurrence, Reminder, Calendar, Reminder List, Permission Proxy, Agent)
  - docs/adr/0001-split-calendar-and-reminders-modules.md
  - docs/adr/0002-timed-events-are-utc-instants-all-day-are-dates.md
  - docs/adr/0003-calendar-mcp-security-posture.md
  - docs/adr/0004-calendar-reminders-v1-scope.md
---

# hs.calendar + hs.reminders modules & Calendar MCP permission proxy

> *This PRD was produced by AI (Claude Code) during a grilling + domain-modeling session, then
> reviewed by a human. Terminology follows `CONTEXT.md`; decisions are recorded in `docs/adr/0001–0004`.*

## Problem Statement

Local AI **Agents** can't touch my macOS Calendar or Reminders. A Claude Code session — especially
one running under a headless launchd daemon such as `herdr-mobile-server` — has no GUI session, so
macOS never shows it the Calendar/Reminders consent prompt and denies it outright. macOS ties this
access to the responsible GUI app, and a daemon simply isn't one. I want my Agents to read and
manage my calendar and reminders, but the OS permission model locks every one of them out.

## Solution

Hammerspoon 2 — a persistent, signed GUI app I already run — holds the durable Calendar/Reminders
grant and acts as a **Permission Proxy**. My Agents speak MCP over loopback HTTP to HS2, and HS2
performs the EventKit operations under its own identity. I grant access once in HS2 (a one-time human
click); from then on any local Agent can create, read, update, and delete **Events** and **Reminders**
through a small set of MCP tools, without ever needing its own TCC grant.

Two native modules do the EventKit work — `hs.calendar` (Events) and `hs.reminders` (Reminders) — and
one vibecast feature, `calendar-mcp`, exposes them as MCP tools over a loopback `hs.httpserver`.

```
Agent (herdr daemon / Claude Code — NO calendar TCC)
      │  MCP over HTTP @ 127.0.0.1 + Bearer token
      ▼
Hammerspoon 2 (GUI app — HAS calendar TCC)          ← Permission Proxy
      ├─ vibecast feature: calendar-mcp  (JS on hs.httpserver)  → POST /mcp
      └─ hs.calendar + hs.reminders  (Swift / EventKit)         → EKEventStore
                                                                     ▼
                                                        macOS Calendar & Reminders
```

## User Stories

**Permission (Phase 0)**

1. As the HS2 user, I want to grant Calendar access to HS2 once via a system prompt, so that my Agents can use it durably without re-prompting.
2. As the HS2 user, I want to grant Reminders access separately from Calendar, so that the two scopes are controlled independently.
3. As the HS2 user, I want the grant to persist across HS2 relaunches and appear in System Settings › Privacy & Security › Calendars under *Hammerspoon 2*, so that I can see and revoke it.
4. As a Hammerspoon scripter, I want `hs.calendar.authorizationStatus()` / `hs.reminders.authorizationStatus()` to report the real EventKit state (`fullAccess` / `writeOnly` / `denied` / `restricted` / `notDetermined`), so that I can branch on exactly why access is or isn't available.
5. As a Hammerspoon scripter, I want `hs.permissions.requestCalendar()` / `requestReminders()` to return a Promise resolving to `true`/`false`, so that I can await the grant result.
6. As a Hammerspoon scripter, I want `hs.permissions.checkCalendar()` / `checkReminders()` to return a boolean synchronously, so that I can gate features without awaiting.

**Events — `hs.calendar`**

7. As an Agent, I want to list all Calendars with `id`, `title`, `writable`, and `isDefault`, so that I can choose where to create Events and disambiguate same-named Calendars.
8. As an Agent, I want to list Events in a Calendar between two instants, so that I can see what's scheduled in a window.
9. As an Agent, I want listed Events as plain objects with a stable `id`, `title`, `start`, `end`, `allDay`, `location`, `notes`, `url`, and read-only `attendees`/`organizer`/`status`, so that I can present and act on them.
10. As an Agent, I want each returned Event flagged `recurring: true/false` with its `occurrenceStart`, so that I know whether an `id` addresses a single Event or a series **Occurrence**.
11. As an Agent, I want to create a single (non-recurring) Event with `title`/`start`/`end` and optional `allDay`/`location`/`notes`/`url`/`alarms`, so that I can schedule something for the user.
12. As an Agent, I want to set minutes-before `alarms` on an Event I create, so that the user is reminded beforehand.
13. As an Agent, I want to update an existing single Event's fields by `id`, so that I can reschedule or edit it.
14. As an Agent, I want to delete an Event by `id`, so that I can cancel it.
15. As an Agent, I want to search Events by text query within a time range, so that I can find one without knowing its `id`.
16. As an Agent, I want to omit the Calendar when creating an Event and have it land in the default Calendar, so that the simple case is a single call.
17. As an Agent, I want to pass either a Calendar `id` or a Calendar `title`, so that I can use the friendly name and fall back to the stable id when it's ambiguous.
18. As an Agent, I want a clear error listing candidate Calendars (with ids) when a title I passed is ambiguous, so that I can retry with a specific id.
19. As an Agent, I want writing to a read-only Calendar to fail loudly, so that I don't silently lose an Event.

**Reminders — `hs.reminders`**

20. As an Agent, I want to list Reminder Lists with `id`/`title`/`writable`/`isDefault`, so that I can choose where to create Reminders.
21. As an Agent, I want `listReminders` to default to incomplete-only, so that I see what's outstanding without a flood of completed history.
22. As an Agent, I want to explicitly request completed or incomplete Reminders, so that I can review either set.
23. As an Agent, I want to create a Reminder with `title` and optional `due`/`priority`/`notes`, so that I can add a task for the user.
24. As an Agent, I want to set `priority` as `none`/`low`/`medium`/`high`, so that I don't have to know EventKit's 0–9 integers.
25. As an Agent, I want a `due` value that can be a day only or a day + time, so that both "due Tuesday" and "due Tuesday 3pm" are expressible.
26. As an Agent, I want to complete a Reminder by `id`, so that I can check it off.
27. As an Agent, I want to delete a Reminder by `id`, so that I can remove it.

**Dates & correctness**

28. As an Agent, I want timed Events/Reminders to be UTC instants, so that there's no ambiguity about *when* something is.
29. As an Agent, I want a naked datetime (no UTC offset) to be rejected with a clear message, so that I never silently create a wrong-time item.
30. As an Agent, I want all-day Events and day-only due dates expressed as plain `YYYY-MM-DD` dates, so that they don't drift across timezones.

**MCP transport**

31. As an Agent, I want to discover the calendar/reminder tools via MCP `tools/list`, so that they appear automatically in my session.
32. As an Agent, I want each tool call to return structured JSON plus a text summary, so that both the model and downstream tooling can consume the result.
33. As an Agent, I want a *tool* failure (read-only Calendar, not-found, naked datetime, edit of a recurring series) returned as an `isError` result with a helpful message, so that I can self-correct instead of crashing.
34. As an Agent, I want a *protocol* failure (unknown method/tool, malformed request) returned as a JSON-RPC error, so that transport errors are distinguishable from tool errors.
35. As an Agent, I want destructive tools (`delete_event`, `delete_reminder`) to prompt the user before running, so that nothing irreversible happens without consent.
36. As an Agent, I want the endpoint to speak stateless Streamable HTTP (one POST, one JSON response), so that no session handshake state is needed.
37. As a herdr-daemon Agent with no Calendar TCC, I want to create and later delete an Event through HS2, so that I can manage the calendar despite having no grant of my own.

**Security**

38. As the HS2 user, I want the MCP endpoint bound to loopback and gated by a Bearer token, so that only local, authorized clients can touch my calendar.
39. As the HS2 user, I want the token minted into Keychain rather than sitting in plaintext config, so that it isn't leaked if my config is ever synced to a dotfiles repo.
40. As the HS2 user, I want a wrong/missing token to get `401` and a browser-style cross-origin request rejected, so that a malicious web page can't drive my calendar.
41. As the HS2 user, I want `calendar-mcp` disabled by default and enabled only via my vibecast config, so that nothing is exposed until I opt in.

**Operational**

42. As the HS2 user, I want a clear "grant Calendar access in Hammerspoon 2" error when access is missing, so that I know the one-time human step to take.
43. As the HS2 user, I want documented instructions for wiring `HS_MCP_TOKEN` into my shell profile and the herdr launchd plist, so that both interactive and daemon Agents can authenticate.
44. As an Agent, I want a connection failure (HS2 not running) surfaced as a tool error, so that I can tell the user to launch HS2.

**Developer**

45. As a developer, I want integration tests that verify the JS↔Swift contract without needing real TCC, so that CI stays green on a runner with no grant.
46. As a developer, I want live-CRUD tests to run only when access is granted and to clean up after themselves in a throwaway Calendar/Reminder List, so that they never pollute a real calendar.
47. As a developer, I want the MCP router unit-tested as a pure function, so that protocol and guard behavior is covered without a running server or EventKit.
48. As a maintainer, I want docs regenerated after the change, so that the generated JS API docs stay in sync with the code.

## Implementation Decisions

**Module boundary (ADR-0001).** Two native modules — `hs.calendar` (Events) and `hs.reminders`
(Reminders) — not one combined module and not `hs.eventkit`. They share a single `EKEventStore`
internally. Both follow the standard HS2 module pattern (JSExport API protocol + implementation class
with `name`/`init(engineID:)`/`shutdown()`, registered in `ModuleRoot`, modeled on `hs.location`).

**Permissions.** `PermissionsManager` gains **two** new cases — `calendar` and `reminders` — appended
after the last existing case to preserve raw values, and handled in each of its switch sites plus the
manager's cases test. `hs.permissions.checkCalendar/requestCalendar/checkReminders/requestReminders`
mirror the `.location`/`.notifications` shape: `check*()` → `boolean`; `request*()` → `Promise<boolean>`
(true = full access granted). We request **full** access (`requestFullAccessToEvents` /
`…Reminders`) because the proxy's read tools need it; the write-only request path is not implemented.

**Authorization status.** `authorizationStatus()` on each module returns the real EventKit state as a
string: `hs.calendar` → `fullAccess` | `writeOnly` | `denied` | `restricted` | `notDetermined`;
`hs.reminders` → the same minus `writeOnly` (EventKit has no write-only reminders scope). Reporting
lives on the modules; requesting lives in `hs.permissions` (the `hs.location` division of labor).

**Info.plist / usage strings.** Usage-description strings are added as `INFOPLIST_KEY_…` **build
settings** in both the Debug and Release app-target configs (the repo's convention — *not* an edit to
`Hammerspoon-2-Info.plist`): `NSCalendarsFullAccessUsageDescription` and
`NSRemindersFullAccessUsageDescription`. The app is unsandboxed, so no entitlement is required. (A
missing key makes the request deny synchronously with no prompt.)

**Dates (ADR-0002).** Timed Events/Reminders are **UTC instants**: input ISO 8601 must carry an
explicit offset or `Z` — a naked datetime is rejected with an `isError` result — and output is UTC `Z`.
All-day Events and day-only Reminder due dates are **date-only `YYYY-MM-DD`** in and out, never
round-tripped through a datetime.

**Event identity & recurrence (v1 scope, ADR-0004).** `createEvent` creates single (non-recurring)
Events only. `listEvents`/`searchEvents` return each **Occurrence** in range (EventKit auto-expands),
tagged `recurring` with `occurrenceStart`. `updateEvent`/`deleteEvent` take an `id`; if it resolves to
a recurring series they return an `isError` explaining that recurring-series editing is unsupported in
v1, rather than guessing an EventKit `span`.

**Event fields.** Writable: `title`, `start`, `end`, `allDay`, `location`, `notes`, `url`, `alarms`
(a minutes-before array, e.g. `[10, 60]`). Read-only on output: `attendees`, `organizer`, `status`,
`availability`. Attendees are never settable (EventKit has no supported programmatic add path).

**Calendar / Reminder List identification.** The `calendar` (or `list`) argument accepts **either** a
stable id **or** a title. Resolve id-first; if no container has that identifier, match by title. A
title matching multiple containers → `isError` listing the candidates with ids. A read-only target, or
an omitted argument with no default container, → `isError`. Omitted → the default container.
`listCalendars()` / `listReminderLists()` return `{ id, title, writable, isDefault }`.

**Reminder fields.** `priority` is `none` | `low` | `medium` | `high`, mapped to EventKit's canonical
ints on write (none=0, high=1, medium=5, low=9) and bucketed on read (1–4→high, 5→medium, 6–9→low,
0→none). `due` accepts date-only or a strict instant (per ADR-0002). `listReminders(list, completed?)`:
omitted → incomplete only; `true` → completed; `false` → incomplete.

**MCP feature `calendar-mcp` (vibecast).** Mirrors `features/devbridge/`: an `index.js` that starts
`hs.httpserver.serve` on `127.0.0.1` and adapts the Fetch `Request` into a plain object, plus a **pure
`route()`** function (no `hs`) holding the guards and JSON-RPC dispatch. Registered by adding the
kebab-case dir name **`calendar-mcp`** to the vibecast `FEATURES` list; its config block is keyed
**`calendar-mcp`** (the loader gates on `cfg[dirName].enabled`, so the plan's camelCase `calendarMcp`
would be silently ignored). Config: `{ enabled: false (default), port: 8562 }`. The request body is read
with `JSON.parse(await req.text())` inside a try/catch that returns **400** on malformed JSON (not the
raw `req.json()`, which surfaces as 500).

**MCP protocol.** One endpoint, `POST /mcp`, stateless, no SSE, no sessions. Handles `initialize`
(declaring `capabilities.tools.listChanged: false`, `serverInfo`, echoed `protocolVersion`),
`notifications/initialized` → **202** no body, `tools/list`, `tools/call`, `ping`. `GET /mcp` → **405**.

**MCP tools.** snake_case `verb_noun`, disambiguated by noun (no prefix): `list_calendars`,
`list_events`, `create_event`, `update_event`, `delete_event`, `search_events`, `list_reminder_lists`,
`list_reminders`, `create_reminder`, `complete_reminder`, `delete_reminder`, plus an
authorization-status tool. `delete_event`/`delete_reminder` carry
`_meta: { "anthropic/requiresUserInteraction": true }`. Each tool wraps an `hs.calendar.*` /
`hs.reminders.*` call. Result contract:

```
{ content: [{ type: "text", text: <JSON string> }], structuredContent: <result obj>, isError: <bool> }
```

A tool failure (read-only container, not found, naked datetime, recurring-series edit, access missing)
→ result with `isError: true` and a human-readable message. A protocol failure (unknown method/tool,
malformed JSON-RPC) → a JSON-RPC error object `{ code, message }`.

**MCP security (ADR-0003).** Bind `127.0.0.1` and assert `req.remoteAddress` is loopback. `Authorization:
Bearer <token>` is the primary gate, compared constant-time (mismatch/absent → **401**) — not
`devbridge`'s custom `X-Devbridge-Token`. The token is **Keychain-minted** on first enable (mirroring
`clippad`/`webhook`), revealed once so the user can export `HS_MCP_TOKEN`. Origin is applied leniently:
reject only a real web origin (`http`/`https`) that isn't a loopback host (→ **403**); absent/non-web
Origins pass. Client registration is an `.mcp.json` `http` server pointing at `http://127.0.0.1:8562/mcp`
with `Authorization: Bearer ${HS_MCP_TOKEN}`.

**Async bridging.** EventKit access requests return `JSPromise` via `wrapAsyncInJSPromise`; JS runs on
the main thread, so calls into `@MainActor` code use `MainActor.assumeIsolated { }`. Logging uses
`AKTrace`/`AKError`/`AKWarning`, never `print`.

## Testing Decisions

**What a good test is here.** Tests exercise **external behavior through the highest seam**, never
implementation internals: for the modules that means the JS-facing contract (does `hs.calendar.createEvent(...)`
create and return the right shape?), and for the MCP layer that means the wire behavior (does this
JSON-RPC request produce this response / status?). No mocking of EventKit itself.

**Seam 1 — `JSTestHarness`** (existing seam; Swift/JavaScriptCore side). Two suites per module, following
the `hs.location` + `hs.camera` prior art:
- An **always-on structure suite** — the API methods exist and `authorizationStatus()` returns one of
  the documented strings. Runs everywhere, including CI with no grant (mirrors `HSLocationIntegrationTests`).
- A **gated live-CRUD suite** — `.disabled(if: EKEventStore.authorizationStatus(for:) != .fullAccess)`
  (mirrors `hs.camera`'s `.disabled(if:)` hardware/permission gating). It creates/reads/updates/deletes
  in a **dedicated throwaway Calendar / Reminder List** and removes it in teardown, so a real calendar is
  never polluted. Promise-returning paths are driven and polled with the harness's `waitForAsync`.
- `PermissionsManager`'s new `calendar`/`reminders` cases are covered by extending the existing
  cases/metadata test (prior art: `PermissionsManagerTests`).

**Seam 2 — the pure `route()` function** (existing pattern; vibecast/Node side). A dependency-injected
pure function tested with a fake `req` POJO and fake `calendar`/`reminders` deps, mirroring
`features/devbridge/index.test.js`. Covers: `initialize`/`tools/list`/`tools/call`/`ping`,
`notifications/initialized` → 202, `GET /mcp` → 405, the guards (401 bad/absent token, 403 web-origin,
loopback assertion), and the `isError`-vs-JSON-RPC-error mapping. No `hs`, no EventKit, no live server.

**Not an automated seam.** The real `route → hs.calendar` wiring and the durable TCC grant are verified
by the **Phase 4 manual end-to-end test**: a Claude Code session — ideally one under the herdr daemon —
lists the tools and round-trips a `create_event` / `delete_event` into Calendar.app.

## Out of Scope

Per **ADR-0004** (each reversible additively later):

- **Recurring-event authoring or editing** — no `recurrence` rule on create; edits/deletes to a
  recurring series are rejected (read still expands Occurrences).
- **Attendee/organizer setting** — read-only on output only.
- **Writable availability** (busy/free) — read-only on output only.
- **Reminder alarms** — Events accept `alarms`; Reminders do not in v1.
- **Write-only calendar access** — full access only; no write-only request path or its Info.plist key.
- **Cloud reachability** — loopback only; claude.ai cannot reach `127.0.0.1` (that would need a public
  HTTPS tunnel + OAuth). Local Agents only.
- **Streaming / stateful MCP** — no SSE, no sessions.
- **HS2 auto-launch** — HS2 must already be running; a down proxy surfaces as a client connection error.

## Further Notes

- **Phasing** (verify each before the next): Phase 0 permission plumbing → Phase 1 `hs.calendar` Events
  CRUD → Phase 2 `hs.reminders` CRUD → Phase 3 `calendar-mcp` MCP endpoint → Phase 4 wire + end-to-end
  verify. Phase 0's acceptance is a durable grant visible in System Settings under *Hammerspoon 2*.
- **Docs pipeline.** Every public API protocol method needs a `///` doc comment with `- Parameter:`,
  `- Returns:`, and a ` ```js ` `- Example:` block. Run `npm run docs:generate` after changes;
  `npm run docs:coverage` must pass.
- **AI disclosure (AI_POLICY.md).** This lands in the maintainer's own fork, so it's their call. If any
  of this is ever proposed upstream to `cmsj/Hammerspoon2`, disclose the AI tool and extent of assistance,
  keep a human-in-the-loop who fully understands the code, and trim AI verbosity.
- **Tracking (see ADR-0005).** This feature spans two repos and its execution is tracked on the private
  `happyjake/vibecast` tracker — where the `calendar-mcp` composition and personal agent/herdr wiring
  belong. The native `hs.calendar`/`hs.reminders` module work lands in the `happyjake/Hammerspoon2` fork.
  The upstream-portable design — `CONTEXT.md` and ADRs 0001–0005 — stays committed in the HS2 repo.
  (Re-homed from `happyjake/Hammerspoon2#4`.)
