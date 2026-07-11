# HS2 owns the calendar primitives; vibecast owns the MCP composition

The Calendar/Reminders Permission Proxy is split across two repos along a
**capability vs composition** line.

- **HS2 owns the capability** — the native `hs.calendar` / `hs.reminders` modules
  (EventKit CRUD). This half is *forced, not chosen*: EventKit is a native framework and
  the durable TCC grant is bound to a signed GUI app's bundle id, so the proxy's EventKit
  hands cannot live in vibecast (which is JS config running on HS2). These modules are
  general-purpose and upstreamable to `cmsj/Hammerspoon2`.
- **vibecast owns the composition** — the `calendar-mcp` feature: an `hs.httpserver`-based
  MCP server exposing `hs.calendar.*` / `hs.reminders.*` as MCP tools, with the bearer
  token, tool taxonomy, and herdr wiring.

The boundary falls where change-rate and audience diverge. The primitives are stable and
general (they change rarely and benefit every HS2 user); the MCP composition is opinionated
and personal (an evolving tool surface, off-by-default, tuned by a JS relaunch rather than
an Xcode rebuild). vibecast already hosts loopback HTTP features on `hs.httpserver`
(`devbridge`, `webhook`, `clippad`), so `calendar-mcp` is the same shape with a proven
template.

Rejected: a **native-in-HS2 MCP server**. One repo / one PR / one test environment is
simpler, but it scope-creeps HS2 core with an opinionated agent gateway, slows iteration on
the evolving tool surface, and ships an MCP server to every HS2 user. That only wins if this
were a shipped HS2 *product* feature rather than a personal proxy, or if single-repo
cohesion outweighed the split — neither holds for this goal.

Consequence: the feature spans two repos (two test seams, two review surfaces). The
cross-repo coordination cost is accepted in exchange for clean, upstreamable primitives and
fast iteration on the composition.
