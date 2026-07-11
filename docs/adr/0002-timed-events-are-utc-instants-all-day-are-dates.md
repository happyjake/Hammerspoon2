# Timed events are UTC instants; all-day events are dates

The `hs.calendar` API is consumed mainly by AI Agents, for whom an ambiguous datetime
silently produces a wrong-time Event. So we fix an unambiguous date model:

- **Timed events are instants.** On input, an ISO 8601 datetime **must** carry an
  explicit UTC offset or `Z`; a naked datetime (no offset) is rejected with an `isError`
  result telling the caller to include one. On output, timed Events are emitted as UTC
  `Z`.
- **All-day events are dates.** With `allDay: true`, start/end are date-only
  `YYYY-MM-DD` in and out, never round-tripped through a datetime (which would produce
  the classic off-by-one across timezones).

We chose fail-loud over guess: rejecting an offset-less datetime beats assuming
system-local and creating an Event an hour off that the user discovers later.

Rejected: **timezone-preserving** (honor/emit each Event's local offset + a `timeZone`
field — faithful to "2pm Pacific" intent, but reintroduces the naked-input ambiguity we
want to forbid) and **local-simple** (everything in system-local time — breaks for
cross-timezone scheduling and when the user travels).

Consequence: the Event's original timezone *intent* is not preserved — a caller that
needs "this is a Pacific meeting" must track that itself. This is reversible additively
(an optional `timeZone` field could be added later), but the UTC-`Z` output format is a
fixed contract.
