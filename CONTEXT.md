# Hammerspoon 2 — Domain Glossary

A living, opinionated glossary of domain terms used across Hammerspoon 2 modules,
grouped by area. This file is a glossary only — no implementation details and no
decisions (those live in `docs/adr/`).

## Calendar & Reminders

**Event**:
A span of time that belongs to a Calendar (an `EKEvent`). Has a start and end, or is
marked all-day.
_Avoid_: appointment, meeting, calendar entry

**Occurrence**:
A single materialized instance of a recurring Event within a queried time range. All
Occurrences of one series share that series' identifier, so an identifier alone cannot
address a single Occurrence.
_Avoid_: instance, recurrence

**Reminder**:
A task that belongs to a Reminder List (an `EKReminder`). May carry an optional due
date and a priority, and can be completed. A Reminder is **not** an Event and does not
belong to a Calendar.
_Avoid_: todo, alarm

**Calendar**:
A named container that Events belong to (an `EKCalendar` scoped to events). The
`hs.calendar` module is named after this concept. "Calendar" never means the whole
feature area and never means Reminders.
_Avoid_: using "calendar" as an umbrella over Reminders

**Reminder List**:
A named container that Reminders belong to (an `EKCalendar` scoped to reminders,
surfaced to users as a "list" in Reminders.app).
_Avoid_: calling it a "calendar"

**Permission Proxy**:
Hammerspoon 2's role in this feature — a persistent GUI app that holds the durable
Calendar/Reminders access grant and performs Event and Reminder operations on behalf of
local Agents that cannot obtain that grant themselves.
_Avoid_: broker (informal only), server

**Agent**:
A local AI process (a Claude Code session, or a headless launchd daemon such as
`herdr-mobile-server`) that reaches the Permission Proxy over loopback MCP and cannot
hold its own Calendar/Reminders grant.
_Avoid_: client (ambiguous — also means an MCP client library)
