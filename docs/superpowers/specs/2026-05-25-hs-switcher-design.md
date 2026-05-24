# `hs.switcher` — production-grade window/app switcher

**Status:** design approved 2026-05-25
**Replaces:** the ad-hoc `features/windows/switcher.js` in vibecast and the synchronous AX iteration in `hs.window.{allWindows,orderedWindows,windowsForApp}`

## 1. Goals

Make `ctrl×2` (or any other configurable trigger) a credible drop-in replacement for cmd+Tab — better, because it spans windows as well as apps, and it isn't crippled by a single misbehaving app's AX timeout.

Specifically:
- Pressing the trigger surfaces a picker that's already populated with current MRU state — no AX work on the hot path.
- Cycling with the modifier feels weightless (sub-frame highlight updates).
- Falling back to typing reveals every window across every app via substring filter.
- One misbehaving app (Preview hung on AX, an Electron process that doesn't expose windows) never freezes the UI or empties the picker.

## 2. Non-goals

- Full cmd+Tab visual fidelity (icon-only horizontal strip). We render a list with icons + titles, which is the point.
- App launch from the picker. Only running apps are listed. Spotlight/Raycast already do launching.
- Window previews (thumbnails). Defer; AX/CGS thumbnail capture is expensive and rarely necessary.
- Persistent MRU across HS restarts. Session-only is fine.

## 3. UX

### Trigger
- Default: `ctrl×2` (existing `hs.hotkey.bindDoubleTap('ctrl', …)` shape).
- Future-extensible: `hold:cmd+space`, `hold:opt+tab`, etc. Out of scope for v1.

### Default selection on open
- `MRU[1]` app's `MRU[0]` window — the "previous window," matching cmd+Tab muscle memory.
- If MRU has only one app (just-launched session): select that app's `MRU[1]` window if it exists, else `MRU[0]`.
- If the snapshot is empty, do nothing visible. No empty popup.

### Cycle mode (default — no typing yet)
| Input | Effect |
|---|---|
| `ctrl-tap` | Next app, wraps. |
| `shift+ctrl-tap` | Previous app. |
| `→` / `←` | Next / previous app (alias for ctrl-tap, friendlier for mouse-thinkers). |
| `↓` / `↑` | Next / previous window within highlighted app. |
| `ctrl released, idle ≥ 250 ms` | Commit: focus the highlighted window, raise its app. |
| `Escape` | Cancel. |
| Mouse click on row | Commit. |
| Click outside picker | Cancel. |

### Filter mode (entered the moment a non-cycle key is typed)
- Letter typed → filter mode. A search header appears with the typed string.
- Filter matches **both** app name and window title, case-insensitive substring. (Future: fuzzy.)
- Selection rule when filter changes:
  - If current selection still matches → keep it.
  - Else → select top match.
- In filter mode:
  - Ctrl release **no longer** commits.
  - `Enter` commits.
  - `Escape` cancels.
  - `Backspace` edits the filter; emptying it exits filter mode back to cycle mode.
  - `↓` / `↑` still navigate filtered results.

### Safety
- 15 s hard timeout: picker auto-dismisses if untouched. Defends against eventtap zombies.
- Any commit / cancel / timeout tears down eventtap and popup **atomically**. No half-dismissed states.

## 4. Performance budgets

These are the non-negotiable targets that drive the architecture. If we can't hit them, we ship nothing.

| Action | Budget | Rationale |
|---|---|---|
| trigger → picker visible | < 30 ms | cmd+Tab feels instant; > 50 ms feels broken |
| ctrl-tap → highlight moves | < 8 ms | one frame at 120 Hz |
| filter keystroke → list updates | < 16 ms | one frame at 60 Hz |
| commit → window focused | < 50 ms | one bounded AX call |
| steady-state CPU when idle | ≈ 0 % | observer-based; no polling |

## 5. Architecture

### 5.1 `HSWindowRegistry` — long-lived in-memory MRU cache

Lives inside `HSWindowModule` (no new module yet — it's window state). One instance per JS engine; main-actor-isolated since AX bookkeeping and SwiftUI both touch main.

**Data model**
```
HSWindowRegistry
  appsByPid: [pid_t: HSAppEntry]
  appMRU:    [pid_t]                     // most-recent first

HSAppEntry
  pid: pid_t
  name: String                            // cached, from NSRunningApplication
  icon: NSImage?                          // cached
  bundleID: String?
  windows: [HSWindowEntry]                // MRU-ordered
  observer: AXObserver?                   // nil if install failed; we fall back to polled refresh
  lastActivatedAt: Date

HSWindowEntry
  axRef: AXUIElement
  stableID: UInt                          // monotonic counter; AX has no stable window IDs
  title: String                           // cached
  lastFocusedAt: Date
```

**Maintenance triggers (all cheap, all observer-driven)**

- `NSWorkspace` notifications (no AX):
  - `didLaunchApplicationNotification` → add `HSAppEntry`, install AXObserver, seed windows asynchronously.
  - `didTerminateApplicationNotification` → remove `HSAppEntry`, uninstall observer.
  - `didActivateApplicationNotification` → bump `appMRU` to front, update `lastActivatedAt`.

- Per-app `AXObserver`:
  - `kAXWindowCreatedNotification` → append `HSWindowEntry`.
  - `kAXUIElementDestroyedNotification` (delivered for a window) → remove entry.
  - `kAXFocusedWindowChangedNotification` → bump window MRU within that app's `windows`.
  - `kAXTitleChangedNotification` → update cached title.

**Bounded AX calls (everywhere)**
Every `AXUIElement` we hold gets `AXUIElementSetMessagingTimeout(elem, 0.1)` at acquisition. 100 ms is generous for healthy apps and short enough that one misbehaving app can't freeze a picker open.

**Boot seed**
Initial population runs on `DispatchQueue.global(qos: .userInitiated)`:
- Iterate `NSWorkspace.shared.runningApplications` (cheap, no AX).
- For each, install AXObserver and query `windows()` with the bounded timeout.
- Push results into the registry on main via a serial queue (registry is main-isolated).

The picker can open *before* the seed finishes — it just shows whatever apps the registry has seen so far (always at least the current frontmost app, populated by the activate observer that fires on engine start).

**Fallback for AX-hostile apps**
If `AXObserverCreate` fails or returns an observer that never fires (some sandboxed / Electron apps): the app is still in `appsByPid` with `observer = nil`, and we run a low-frequency (5 s) polled `windows()` refresh **only for those pids**. The vast majority of apps use the observer path and cost nothing.

### 5.2 `HSSwitcherSession` — per-invocation picker

One instance per ctrl×2; lives until commit, cancel, or 15 s timeout.

**Owns**
- `CGEventTap` for global keyboard capture.
- Current snapshot (pointer-copy from `HSWindowRegistry` taken at open time — O(apps) on the main thread, well under the 30 ms budget).
- Selection state: `(appIndex, windowIndex, mode: .cycle | .filter, filterText)`.
- The `HSUIWindow` showing the picker.

**Eventtap callback stays entirely in Swift.** The hot path never crosses the JS bridge. We only call into JS at commit (and only if `onCommit` was provided).

**Key pass-through discipline**
The eventtap consumes only keys it handles for the current mode:
- **Cycle mode**: consumed = ctrl flag-change events, arrows, Escape, and any plain ASCII letter/digit (no modifiers). Plain letters are consumed because they're the trigger to enter filter mode — letting them through would deliver the first letter to the underlying app instead of capturing it as the start of the filter string. Anything else (cmd-shortcuts, function keys, etc.) passes through untouched.
- **Filter mode**: all keyDown events consumed — we own the keyboard now.

**Commit / cancel / timeout** all funnel through one teardown path that:
1. Stops + releases the eventtap.
2. Closes the `HSUIWindow`.
3. Removes the 15 s safety timer.
4. Calls `onCommit(entry)` or `onCancel()` if registered.

### 5.3 SwiftUI rendering

- Uses existing `hs.ui` primitives (`HSUIWindow`, `UIVStack`, `UIHStack`, `UIText`, `UIImage`) — no new view layer.
- Picker state (selection index, filter string, mode) lives in a dedicated `@Observable` class held by `HSSwitcherSession`. SwiftUI's dependency tracking re-renders only the rows that actually observe the changed properties (highlighted-row background, search-header text). Sibling rows are untouched per the existing `Reactive*` pattern in `hs.ui`.
- Row list rendered in a `LazyVStack` so 200 windows doesn't instantiate 200 row views up front.

### 5.4 JS API

Surface area is deliberately tiny — vibecast keeps owning user config.

```js
const session = hs.switcher.enable({
  trigger: 'ctrl-double',              // v1 only supports this; extensible later
  commitDelayMs: 250,                  // ctrl-idle duration that triggers commit
  filterPlaceholder: 'Type to filter…',
  onCommit: (entry) => { /* { appName, appPid, windowTitle, windowID } */ },
  onCancel: () => {},
})
// returns: { disable() } | { error: 'inputMonitoring' | 'accessibility' | string }
```

Also exposed for general use:
```js
hs.window.snapshot()
// → [{ pid, name, bundleID, icon: <data url>, windows: [{ id, title }] }]
// Reads directly from HSWindowRegistry. O(apps + windows). No AX calls.
```

The existing `hs.window.{allWindows,orderedWindows,windowsForApp}` are kept (back-compat) but their internal `getWindowElements` gets `AXUIElementSetMessagingTimeout` applied — fixing the original freeze for any other consumer.

## 6. Failure modes

| Failure | Behavior |
|---|---|
| AX call times out for one app | Skip that app's windows this tick; registry retries on next observer fire. Other apps unaffected. |
| AXObserver install fails for an app | App stays in registry with `observer = nil`; 5 s polled refresh applies just to that pid. |
| App ignores AX entirely (no windows ever observed) | App row still shows in picker (we have icon+name from `NSRunningApplication`); commit falls back to `NSRunningApplication.activate(options:)`. |
| Input Monitoring permission missing | `hs.switcher.enable()` returns `{ error: 'inputMonitoring' }`. Picker never installs. Caller logs / notifies user. |
| Accessibility permission missing | Same shape: `{ error: 'accessibility' }`. |
| User Cmd-Tabs away while picker is open | Picker cancels (we observe `NSWindow` `resignKey`). |
| Eventtap silently disabled by OS (happens after timeout / heavy load) | We re-enable it lazily on next session; ongoing session detects via `kCGEventTapDisabled*` and tears down. |
| Picker stuck (shouldn't happen, but…) | 15 s safety timer always fires. |

## 7. Implementation order (incremental)

Each step ships independently and is independently testable.

1. **Quick fixes (today, < 1 hour)** — restores baseline correctness for the existing switcher and any other `hs.window` consumer.
   - `HSWindowModule.getWindowElements`: apply `AXUIElementSetMessagingTimeout(_, 0.1)` to the AX element.
   - `vibecast/features/windows/switcher.js`: only `return true` for keys actually handled; add 15 s safety auto-cleanup; close eventtap on click-outside.

2. **`HSWindowRegistry`** — live MRU cache.
   - Data model, NSWorkspace observers, per-app AXObserver install/uninstall.
   - Background seed.
   - Polled fallback for AX-hostile apps.
   - Expose `hs.window.snapshot()` for inspection / JS-side iteration.
   - Tests: spawn fake-app fixtures, verify MRU bumps, verify timeout-protected calls don't hang.

3. **`HSSwitcherSession` + `hs.switcher.enable()`** — Swift-owned picker.
   - Session lifecycle (eventtap, popup, safety timer).
   - Cycle-mode state machine.
   - Filter-mode state machine + substring matcher.
   - SwiftUI list view using existing hs.ui primitives.
   - Commit path: `NSRunningApplication.activate` + AX `AXUIElementPerformAction(_, kAXRaiseAction)` on the window.
   - Tests: drive synthetic events through the session, assert selection / commit behavior.

4. **Migrate vibecast** — delete `features/windows/switcher.js`, replace with `hs.switcher.enable(cfg)` in `features/windows/index.js`. Remove the now-unused `listWindows` helper.

## 8. Explicit decisions (so we don't relitigate)

- **First-letter capture in cycle mode**: yes, we consume the keyDown to enter filter mode rather than letting it through to the underlying app. The alternative (let the letter through, require an explicit `:` or `/` to enter filter mode) feels worse — typing should Just Work.
- **commit delay = 250 ms**: long enough to absorb 5-tap-per-second cycling, short enough to feel snappy on commit. Configurable via `commitDelayMs`.
- **No fuzzy matching in v1**: substring is enough and avoids relevance-tuning rabbit holes.
- **No thumbnails in v1**.
- **No keyboard shortcuts beyond the ones listed**: keep the surface area small enough to memorize.
- **Eventtap in Swift, not JS**: non-negotiable for the per-keystroke budget.

## 9. Open questions

None blocking. The following can be revisited after v1 ships:
- Configurable triggers other than `ctrl×2`.
- Fuzzy matching algorithm choice.
- Per-row keyboard shortcut letters (Witch / AltTab-style direct-pick).
- Thumbnails.
- Persisting MRU across HS restarts.
