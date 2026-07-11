# hs.calendar / hs.reminders v1 scope — deliberate exclusions

Recording what is intentionally **out** of v1, so a future reader doesn't mistake these
gaps for oversights. Each is reversible additively.

- **No recurrence authoring or editing.** `createEvent` makes single (non-recurring)
  events only; `listEvents`/`searchEvents` still return expanded Occurrences (read is
  unavoidable), but `updateEvent`/`deleteEvent` reject an id that resolves to a recurring
  series rather than guess an EventKit `span`. Deferred because span semantics
  (`thisEvent`/`futureEvents`/all) plus composite occurrence ids are a design sub-project;
  guessing wrong silently destroys a user's repeating meeting.

- **No attendee or organizer setting.** EventKit has no supported path to add arbitrary
  attendees programmatically (that is the invitation system). Attendees/organizer/status
  are exposed **read-only** on output; never writable.

- **No writable availability (busy/free).** Read-only on output; deferred to keep the
  writable field set small and avoid per-calendar-type availability edge cases.

- **No reminder alarms.** Events accept an `alarms` (minutes-before) field; Reminders in
  v1 are `{list, title, due?, priority?, notes?}` + completion only.

- **Full access only; no write-only path.** We request `requestFullAccessToEvents` because
  the proxy's read tools need it, and skip the write-only request path and its
  `NSCalendarsWriteOnlyAccessUsageDescription` Info.plist key. (`authorizationStatus()`
  still *reports* `writeOnly` if the user somehow granted only that.)

- **Local agents only; not cloud-reachable.** The MCP endpoint binds `127.0.0.1`, so
  claude.ai cannot reach it (that would need a public HTTPS tunnel + OAuth). Targets local
  clients — Claude Code and herdr daemon sessions.

- **Stateless MCP, no streaming.** One `POST /mcp`, single JSON-RPC object per response;
  no SSE, no sessions.
