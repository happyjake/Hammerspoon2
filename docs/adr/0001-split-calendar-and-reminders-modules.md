# Split Calendar and Reminders into separate modules

EventKit exposes Events and Reminders as distinct entity types under distinct
authorization scopes (`.event` vs `.reminder`), and macOS ships them as two separate
apps. We therefore expose them as two JS modules — `hs.calendar` (Events) and
`hs.reminders` (Reminders/tasks) — rather than one `hs.calendar` covering both, or a
framework-named `hs.eventkit`. They share a single `EKEventStore` internally.

We chose the split for API honesty and discoverability: JS users (and the glossary)
think in the two nouns, so one noun per module reads truthfully. The cost is roughly
double the module scaffolding and registration.

The permission plumbing is bifurcated regardless — `PermissionsManager` needs two cases
(`calendar` and `reminders`) either way, because EventKit has two auth scopes — so it
did not weigh on the decision.

Rejected: **one `hs.calendar` covering both** (least scaffolding, but "calendar"
dishonestly umbrellas tasks) and **`hs.eventkit`** (honest but non-idiomatic; HS2 names
modules after user concepts, not frameworks).
