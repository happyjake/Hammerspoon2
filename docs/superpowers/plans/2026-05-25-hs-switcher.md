# `hs.switcher` Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a cmd+Tab-replacement window/app switcher: ctrl×2 opens a Swift-owned picker backed by an observer-driven MRU cache, with sub-frame cycling latency and bounded AX calls so a single misbehaving app can never freeze the UI.

**Architecture:** A long-lived `HSWindowRegistry` inside `HSWindowModule` maintains live MRU state via `NSWorkspace` notifications and per-app `AXSwift.Observer`. Every `AXUIElement` gets `AXUIElementSetMessagingTimeout(_, 0.1)`. A separate `HSSwitcherModule` exposes `hs.switcher.enable(cfg)`; each invocation creates an `HSSwitcherSession` that owns a `CGEventTap` and an `HSUIWindow`, with the event-loop hot path staying entirely in Swift.

**Tech Stack:** Swift 6, AXSwift, SwiftUI, JavaScriptCore. Existing `hs.ui` primitives (`HSUIWindow`, `UIVStack`, etc.) for rendering. Existing `JSTestHarness` for integration tests.

**Spec reference:** `docs/superpowers/specs/2026-05-25-hs-switcher-design.md`

---

## File Map

**Modify:**
- `Hammerspoon 2/Modules/hs.window/HSWindowModule.swift` — apply AX timeout in `getWindowElements`; add `snapshot()` and registry wiring
- `Hammerspoon 2/Modules/hs.window/hs.window.js` — no changes needed (snapshot exposed via Swift)
- `Hammerspoon 2/Engine/ModuleRoot.swift` — register `hs.switcher`
- `/Users/jake/code/vibecast/features/windows/index.js` — swap `openSwitcher` for `hs.switcher.enable(cfg)`
- `/Users/jake/code/vibecast/features/windows/switcher.js` — quick-fix eventtap behavior in Phase 1; deleted in Phase 4

**Create (Swift):**
- `Hammerspoon 2/Modules/hs.window/HSWindowRegistry.swift` — live MRU cache, NSWorkspace+AXObserver maintenance
- `Hammerspoon 2/Modules/hs.window/HSAppEntry.swift` — per-app entry struct/class
- `Hammerspoon 2/Modules/hs.window/HSWindowEntry.swift` — per-window entry struct/class
- `Hammerspoon 2/Modules/hs.switcher/HSSwitcherModule.swift` — module entry, `enable()` API
- `Hammerspoon 2/Modules/hs.switcher/HSSwitcherSession.swift` — per-invocation lifecycle
- `Hammerspoon 2/Modules/hs.switcher/HSSwitcherState.swift` — `@Observable` selection/filter/mode state
- `Hammerspoon 2/Modules/hs.switcher/HSSwitcherView.swift` — SwiftUI list view
- `Hammerspoon 2/Modules/hs.switcher/HSSwitcherKeyHandler.swift` — eventtap install + key routing
- `Hammerspoon 2/Modules/hs.switcher/hs.switcher.js` — minimal JS shim if needed

**Create (Tests):**
- `Hammerspoon 2Tests/IntegrationTests/HSWindowRegistryTests.swift`
- `Hammerspoon 2Tests/IntegrationTests/HSSwitcherTests.swift`
- `Hammerspoon 2Tests/UnitTests/HSSwitcherStateTests.swift` (pure state-machine tests, no JSContext)

**Notes for the implementer:**
- All Swift code that touches AX runs on main actor.
- All `AXUIElement` instances need `AXUIElementSetMessagingTimeout(elem, 0.1)` before use.
- AXSwift `Observer` adds its run-loop source to `RunLoop.current.getCFRunLoop()`, so MUST be created on the main thread.
- The build command from CLAUDE.md is `xcodebuild build -target "Hammerspoon 2" -scheme "Development" -destination 'platform=macOS'`. Test command is identical with `test` instead of `build`.
- After ANY code change, also run `npm run docs:generate` to keep docs synced.

---

# Phase 1 — Quick Fixes

Goal: stop the freeze and the key-eating bug. Ships standalone; the rest of the plan can land later without reverting this.

## Task 1.1: AX messaging timeout in `getWindowElements`

**Files:**
- Modify: `Hammerspoon 2/Modules/hs.window/HSWindowModule.swift:113-125`
- Test: `Hammerspoon 2Tests/IntegrationTests/HSWindowIntegrationTests.swift` (new file)

- [ ] **Step 1: Add a regression test that `hs.window.allWindows()` returns in bounded time**

Create `Hammerspoon 2Tests/IntegrationTests/HSWindowIntegrationTests.swift`:

```swift
//
//  HSWindowIntegrationTests.swift
//  Hammerspoon 2Tests
//

import Testing
import Foundation
@testable import Hammerspoon_2

struct HSWindowIntegrationTests {
    @Test("allWindows returns within 3s even if some apps are AX-hostile")
    func testAllWindowsBoundedTime() async {
        let h = await JSTestHarness()
        await h.loadModule(HSWindowModule.self, as: "window")
        let start = Date()
        _ = await h.eval("hs.window.allWindows()")
        let elapsed = Date().timeIntervalSince(start)
        #expect(elapsed < 3.0, "allWindows took \(elapsed)s — AX timeout not applied?")
    }
}
```

- [ ] **Step 2: Run the test — it should fail or pass depending on whether any AX-hostile app is running. Document baseline.**

Run:
```
xcodebuild test -target "Hammerspoon 2" -scheme "Development" -destination 'platform=macOS' \
    -only-testing:Hammerspoon_2Tests/HSWindowIntegrationTests
```

If it passes, that means no AX-hostile app was hung at test time — the test will still catch regressions if one is. If it fails with timeout, even better confirmation of the bug.

- [ ] **Step 3: Apply the timeout fix**

Edit `Hammerspoon 2/Modules/hs.window/HSWindowModule.swift`, replace lines 113-125 (`getWindowElements`) with:

```swift
private func getWindowElements(for app: NSRunningApplication) -> [UIElement] {
    guard let axApp = Application(app) else {
        return []
    }
    // Bound AX messaging: a misbehaving app cannot freeze the main thread for more
    // than 100 ms per call. Default is 6 s, which froze the UI when Preview hung.
    AXUIElementSetMessagingTimeout(axApp.element, 0.1)

    do {
        let windows: [UIElement] = try axApp.windows() ?? []
        return windows
    } catch {
        AKTrace("Failed to get windows for \(app.localizedName ?? "unknown"): \(error.localizedDescription)")
        return []
    }
}
```

- [ ] **Step 4: Run the test — should pass within budget**

```
xcodebuild test -target "Hammerspoon 2" -scheme "Development" -destination 'platform=macOS' \
    -only-testing:Hammerspoon_2Tests/HSWindowIntegrationTests
```

Expected: PASS in < 3 s.

- [ ] **Step 5: Run full test suite to confirm no regressions**

```
xcodebuild test -target "Hammerspoon 2" -scheme "Development" -destination 'platform=macOS'
```

Expected: all green.

- [ ] **Step 6: Run docs pipeline**

```
cd /Users/jake/code/Hammerspoon2 && npm run docs:generate
```

Expected: no errors.

- [ ] **Step 7: Commit**

```
git add "Hammerspoon 2/Modules/hs.window/HSWindowModule.swift" "Hammerspoon 2Tests/IntegrationTests/HSWindowIntegrationTests.swift" docs/api.json docs/hammerspoon.d.ts
git commit -m "fix(hs.window): bound AX messaging timeout to 100ms

A single hung app (e.g. Preview) could freeze the main thread for the
default 6s AX timeout, blocking key input. Cap per-element timeout at
100ms so the worst case is bounded regardless of which apps are running."
```

## Task 1.2: Fix vibecast switcher.js eventtap behavior

**Files:**
- Modify: `/Users/jake/code/vibecast/features/windows/switcher.js`

- [ ] **Step 1: Replace eventtap callback to only consume handled keys + add safety auto-cleanup**

Edit `/Users/jake/code/vibecast/features/windows/switcher.js`, replace the body of `openSwitcher` (starting at the `eventtapFactory` line through `tap.start()`) with:

```js
  // Safety: auto-cleanup after 15s in case something weird happens (popup not
  // visible, user walked away, etc). Without this, an eventtap that returns
  // `true` to consume all keys can persist forever.
  let safetyTimer = null
  try {
    safetyTimer = hs.timer?.doAfter?.(15, () => cleanup())
  } catch (_) { /* if timer unavailable, picker still works, just no safety */ }

  function cleanup() {
    if (cleaned) return
    cleaned = true
    try { tap.stop() } catch (_) {}
    try { popup?.close?.() } catch (_) {}
    try { safetyTimer?.stop?.() } catch (_) {}
  }

  const tap = eventtapFactory(['keyDown'], (event) => {
    const chars = event?.characters || ''
    // Digit selection
    if (chars >= '1' && chars <= '9') {
      const idx = parseInt(chars, 10) - 1
      if (idx < items.length) {
        try { items[idx].win.focus() } catch (_) {}
        cleanup()
      }
      return true   // consume — we handled it
    }
    // Escape dismisses
    if (event?.keyCode === 53 /* Escape */) {
      cleanup()
      return true   // consume — we handled it
    }
    // Anything else: let it through. Don't eat keys we don't act on.
    return false
  })
  tap.start()
```

Note: `cleaned` must still be declared above; if your current file has `let cleaned = false` already, keep it. If you've reorganised the function, make sure both `cleanup` and `tap` are still in scope for each other.

- [ ] **Step 2: Manually verify in HS2**

In the running Hammerspoon 2 console, reload config:
```js
hs.reload()
```

Then trigger ctrl×2. Expected:
- Picker appears (or doesn't if no windows — both OK).
- Pressing a letter passes through to the underlying app (you can keep typing).
- Pressing 1-9 selects.
- Pressing Escape dismisses.
- After 15 s of inactivity, picker auto-dismisses.

(This is manual because we can't synthesise CGEventTap behaviour in a test harness.)

- [ ] **Step 3: Commit (in vibecast repo)**

```
cd /Users/jake/code/vibecast
git add features/windows/switcher.js
git commit -m "fix(switcher): only consume handled keys; add 15s safety cleanup

The previous tap returned true unconditionally, eating every keystroke
until Escape. Now we pass through anything we don't act on. Safety
timer guards against a stuck popup state."
```

---

# Phase 2 — `HSWindowRegistry` (live MRU cache)

Goal: in-memory MRU state maintained by observers, no AX on the hot path. Exposed via `hs.window.snapshot()`.

## Task 2.1: Define `HSAppEntry` and `HSWindowEntry` data types

**Files:**
- Create: `Hammerspoon 2/Modules/hs.window/HSAppEntry.swift`
- Create: `Hammerspoon 2/Modules/hs.window/HSWindowEntry.swift`

- [ ] **Step 1: Create `HSWindowEntry`**

Create `Hammerspoon 2/Modules/hs.window/HSWindowEntry.swift`:

```swift
//
//  HSWindowEntry.swift
//  Hammerspoon 2
//

import Foundation
import AppKit
import AXSwift

/// One window inside the live registry. Reference type so AXObserver callbacks
/// can mutate `title` / `lastFocusedAt` in place without copy semantics getting
/// in the way.
@MainActor
final class HSWindowEntry {
    let stableID: UInt64
    let axElement: UIElement
    var title: String
    var lastFocusedAt: Date

    init(stableID: UInt64, axElement: UIElement, title: String, lastFocusedAt: Date = Date()) {
        self.stableID = stableID
        self.axElement = axElement
        self.title = title
        self.lastFocusedAt = lastFocusedAt
    }
}
```

- [ ] **Step 2: Create `HSAppEntry`**

Create `Hammerspoon 2/Modules/hs.window/HSAppEntry.swift`:

```swift
//
//  HSAppEntry.swift
//  Hammerspoon 2
//

import Foundation
import AppKit
import AXSwift

/// One app inside the live registry. Holds the AXObserver subscription for that
/// app's window lifecycle events.
@MainActor
final class HSAppEntry {
    let pid: pid_t
    let name: String
    let bundleID: String?
    var icon: NSImage?
    var windows: [HSWindowEntry]      // MRU-ordered, most-recent first
    var lastActivatedAt: Date
    var observer: Observer?           // nil if AXObserverCreate failed for this pid
    var pollTimer: Timer?             // non-nil only when we're using the polled fallback

    init(runningApp: NSRunningApplication) {
        self.pid = runningApp.processIdentifier
        self.name = runningApp.localizedName ?? "Unknown"
        self.bundleID = runningApp.bundleIdentifier
        self.icon = runningApp.icon
        self.windows = []
        self.lastActivatedAt = Date()
        self.observer = nil
        self.pollTimer = nil
    }
}
```

- [ ] **Step 3: Build to verify both files compile**

```
xcodebuild build -target "Hammerspoon 2" -scheme "Development" -destination 'platform=macOS'
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Commit**

```
git add "Hammerspoon 2/Modules/hs.window/HSAppEntry.swift" "Hammerspoon 2/Modules/hs.window/HSWindowEntry.swift"
git commit -m "feat(hs.window): add HSAppEntry/HSWindowEntry types for live registry"
```

## Task 2.2: `HSWindowRegistry` skeleton + NSWorkspace observers

**Files:**
- Create: `Hammerspoon 2/Modules/hs.window/HSWindowRegistry.swift`

- [ ] **Step 1: Create the registry with NSWorkspace observers wired up**

Create `Hammerspoon 2/Modules/hs.window/HSWindowRegistry.swift`:

```swift
//
//  HSWindowRegistry.swift
//  Hammerspoon 2
//

import Foundation
import AppKit
import AXSwift

/// Long-lived, in-memory cache of running apps and their windows, maintained
/// by NSWorkspace notifications and per-app AXObservers. The switcher reads
/// snapshots from here on the hot path — no AX calls at trigger time.
@MainActor
final class HSWindowRegistry {
    private var appsByPid: [pid_t: HSAppEntry] = [:]
    private var appMRU: [pid_t] = []          // most-recent first
    private var nextWindowID: UInt64 = 1
    private var nsObservers: [NSObjectProtocol] = []
    private let seedQueue = DispatchQueue(label: "hs.window.registry.seed", qos: .userInitiated)

    init() {
        installWorkspaceObservers()
        seedInitialApps()
    }

    deinit {
        // Cannot touch main-actor state from non-isolated deinit; rely on
        // process teardown. NSWorkspace observers are released with us.
    }

    // MARK: - Snapshot (hot path; no AX, no blocking work)

    /// Returns the current MRU-ordered list of apps with their windows. Reads
    /// directly from cache; safe to call at picker-trigger time.
    func snapshot() -> [HSAppEntry] {
        return appMRU.compactMap { appsByPid[$0] }
    }

    // MARK: - Workspace observers

    private func installWorkspaceObservers() {
        let nc = NSWorkspace.shared.notificationCenter
        nsObservers.append(nc.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil, queue: .main
        ) { [weak self] notif in
            MainActor.assumeIsolated {
                guard let app = notif.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
                self?.addApp(app)
            }
        })
        nsObservers.append(nc.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil, queue: .main
        ) { [weak self] notif in
            MainActor.assumeIsolated {
                guard let app = notif.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
                self?.removeApp(pid: app.processIdentifier)
            }
        })
        nsObservers.append(nc.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil, queue: .main
        ) { [weak self] notif in
            MainActor.assumeIsolated {
                guard let app = notif.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
                self?.markActivated(pid: app.processIdentifier)
            }
        })
    }

    // MARK: - App mutations

    private func addApp(_ runningApp: NSRunningApplication) {
        let pid = runningApp.processIdentifier
        guard appsByPid[pid] == nil else { return }
        guard runningApp.activationPolicy != .prohibited else { return }
        let entry = HSAppEntry(runningApp: runningApp)
        appsByPid[pid] = entry
        appMRU.append(pid)   // newly-launched goes to tail; activate notification bumps it
        // Window observer + window seed wired in Task 2.3 / 2.4
    }

    private func removeApp(pid: pid_t) {
        appsByPid.removeValue(forKey: pid)
        appMRU.removeAll { $0 == pid }
    }

    private func markActivated(pid: pid_t) {
        guard let entry = appsByPid[pid] else { return }
        entry.lastActivatedAt = Date()
        appMRU.removeAll { $0 == pid }
        appMRU.insert(pid, at: 0)
    }

    // MARK: - Boot seed

    private func seedInitialApps() {
        let running = NSWorkspace.shared.runningApplications
        for app in running where app.activationPolicy != .prohibited {
            addApp(app)
        }
        // Frontmost app goes to MRU head
        if let front = NSWorkspace.shared.frontmostApplication {
            markActivated(pid: front.processIdentifier)
        }
        // Window seeding (AX) happens in Task 2.4 once observers are wired
    }

    // MARK: - Window ID minting

    func mintWindowID() -> UInt64 {
        defer { nextWindowID &+= 1 }
        return nextWindowID
    }
}
```

- [ ] **Step 2: Build**

```
xcodebuild build -target "Hammerspoon 2" -scheme "Development" -destination 'platform=macOS'
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```
git add "Hammerspoon 2/Modules/hs.window/HSWindowRegistry.swift"
git commit -m "feat(hs.window): HSWindowRegistry skeleton with NSWorkspace observers

App-level MRU maintained via launch/terminate/activate notifications.
Window-level AXObserver wiring lands in the next task."
```

## Task 2.3: Per-app AXObserver for window lifecycle

**Files:**
- Modify: `Hammerspoon 2/Modules/hs.window/HSWindowRegistry.swift`

- [ ] **Step 1: Add observer install/uninstall to app mutations**

In `HSWindowRegistry.swift`, replace `addApp` with:

```swift
    private func addApp(_ runningApp: NSRunningApplication) {
        let pid = runningApp.processIdentifier
        guard appsByPid[pid] == nil else { return }
        guard runningApp.activationPolicy != .prohibited else { return }
        let entry = HSAppEntry(runningApp: runningApp)
        appsByPid[pid] = entry
        appMRU.append(pid)
        installObserver(for: entry)
        seedWindows(for: entry)
    }
```

And replace `removeApp` with:

```swift
    private func removeApp(pid: pid_t) {
        if let entry = appsByPid[pid] {
            entry.observer?.stop()
            entry.observer = nil
            entry.pollTimer?.invalidate()
            entry.pollTimer = nil
        }
        appsByPid.removeValue(forKey: pid)
        appMRU.removeAll { $0 == pid }
    }
```

Then add at the end of the class (before the closing brace):

```swift
    // MARK: - AXObserver

    private func installObserver(for entry: HSAppEntry) {
        do {
            let observer = try Observer(processID: entry.pid) { [weak self, weak entry] _, element, notif in
                MainActor.assumeIsolated {
                    guard let self, let entry else { return }
                    self.handleAXEvent(entry: entry, element: element, notification: notif)
                }
            }
            // Subscribe to the notifications we care about. The application element
            // receives windowCreated; per-window elements receive uiElementDestroyed,
            // titleChanged. focusedWindowChanged is on the app element.
            guard let axApp = Application(forProcessID: entry.pid) else {
                observer.stop()
                return
            }
            AXUIElementSetMessagingTimeout(axApp.element, 0.1)
            try? observer.addNotification(.windowCreated, forElement: axApp)
            try? observer.addNotification(.focusedWindowChanged, forElement: axApp)
            entry.observer = observer
        } catch {
            AKTrace("AXObserverCreate failed for pid \(entry.pid) (\(entry.name)): \(error.localizedDescription); falling back to polled refresh")
            installPollFallback(for: entry)
        }
    }

    private func handleAXEvent(entry: HSAppEntry, element: UIElement, notification: UIElement.AXNotification) {
        switch notification {
        case .windowCreated:
            // `element` is the new window
            addWindow(element, to: entry)
            // Subscribe to per-window notifications now that we have the element
            try? entry.observer?.addNotification(.uiElementDestroyed, forElement: element)
            try? entry.observer?.addNotification(.titleChanged, forElement: element)

        case .uiElementDestroyed:
            removeWindow(matching: element, from: entry)

        case .titleChanged:
            if let win = entry.windows.first(where: { $0.axElement == element }) {
                AXUIElementSetMessagingTimeout(element.element, 0.1)
                win.title = (try? element.attribute(.title)) ?? win.title
            }

        case .focusedWindowChanged:
            // `element` may be the new focused window
            bumpWindowMRU(matching: element, in: entry)

        default:
            break
        }
    }

    // MARK: - Window mutations

    private func addWindow(_ element: UIElement, to entry: HSAppEntry) {
        if entry.windows.contains(where: { $0.axElement == element }) { return }
        AXUIElementSetMessagingTimeout(element.element, 0.1)
        let title = (try? element.attribute(.title)) ?? ""
        let win = HSWindowEntry(stableID: mintWindowID(), axElement: element, title: title)
        entry.windows.insert(win, at: 0)
    }

    private func removeWindow(matching element: UIElement, from entry: HSAppEntry) {
        entry.windows.removeAll { $0.axElement == element }
    }

    private func bumpWindowMRU(matching element: UIElement, in entry: HSAppEntry) {
        guard let idx = entry.windows.firstIndex(where: { $0.axElement == element }) else { return }
        let win = entry.windows.remove(at: idx)
        win.lastFocusedAt = Date()
        entry.windows.insert(win, at: 0)
    }
```

- [ ] **Step 2: Add `seedWindows` and polled-fallback stubs (filled in next task)**

Append to the class:

```swift
    // MARK: - Window seeding (initial AX query; bounded by per-element timeout)

    private func seedWindows(for entry: HSAppEntry) {
        // Implemented in Task 2.4 (does async AX iteration off main; results
        // applied on main via mainQueueApply).
    }

    // MARK: - Polled fallback for AX-hostile apps

    private func installPollFallback(for entry: HSAppEntry) {
        entry.pollTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self, weak entry] _ in
            MainActor.assumeIsolated {
                guard let self, let entry else { return }
                self.seedWindows(for: entry)
            }
        }
    }
```

- [ ] **Step 3: Build**

```
xcodebuild build -target "Hammerspoon 2" -scheme "Development" -destination 'platform=macOS'
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Commit**

```
git add "Hammerspoon 2/Modules/hs.window/HSWindowRegistry.swift"
git commit -m "feat(hs.window): per-app AXObserver for window lifecycle

Window create/destroy/title-change/focus-change events maintained via
AXSwift.Observer. Bounded timeouts on every AXUIElement. Polled
fallback stub for AX-hostile apps."
```

## Task 2.4: Window seeding (initial population)

**Files:**
- Modify: `Hammerspoon 2/Modules/hs.window/HSWindowRegistry.swift`

- [ ] **Step 1: Implement `seedWindows`**

Replace the stub `seedWindows` in `HSWindowRegistry.swift` with:

```swift
    private func seedWindows(for entry: HSAppEntry) {
        let pid = entry.pid
        // Query AX on a background queue; results applied on main. Even though
        // we've bounded timeouts to 100ms per call, doing it off main avoids
        // any chance of accidentally blocking the registry's own operations.
        seedQueue.async { [weak self] in
            guard let axApp = Application(forProcessID: pid) else { return }
            AXUIElementSetMessagingTimeout(axApp.element, 0.1)
            let windows: [UIElement] = (try? axApp.windows()) ?? []
            // Collect titles in this background pass too, with the same timeout.
            let seeded: [(UIElement, String)] = windows.map { w in
                AXUIElementSetMessagingTimeout(w.element, 0.1)
                let title = (try? w.attribute(.title) as String?) ?? ""
                return (w, title)
            }
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    self?.applySeed(pid: pid, seeded: seeded)
                }
            }
        }
    }

    private func applySeed(pid: pid_t, seeded: [(UIElement, String)]) {
        guard let entry = appsByPid[pid] else { return }
        // Don't clobber existing entries; just add ones we haven't seen.
        for (element, title) in seeded {
            if entry.windows.contains(where: { $0.axElement == element }) { continue }
            let win = HSWindowEntry(stableID: mintWindowID(), axElement: element, title: title)
            entry.windows.append(win)
            // Subscribe per-window notifications now that we have the element
            try? entry.observer?.addNotification(.uiElementDestroyed, forElement: element)
            try? entry.observer?.addNotification(.titleChanged, forElement: element)
        }
    }
```

- [ ] **Step 2: Build**

```
xcodebuild build -target "Hammerspoon 2" -scheme "Development" -destination 'platform=macOS'
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```
git add "Hammerspoon 2/Modules/hs.window/HSWindowRegistry.swift"
git commit -m "feat(hs.window): async background window seed with bounded AX

Seed runs off main; per-element timeouts bound the worst case to
~100ms per call. Results applied on main without clobbering observed
windows."
```

## Task 2.5: Wire registry into `HSWindowModule` + expose `hs.window.snapshot()`

**Files:**
- Modify: `Hammerspoon 2/Modules/hs.window/HSWindowModule.swift`

- [ ] **Step 1: Add `snapshot()` API to the protocol**

Edit `HSWindowModule.swift`, inside `@objc protocol HSWindowModuleAPI`, add at the end (before the closing `}`):

```swift
    /// Get a snapshot of the live window registry — apps and their windows in
    /// MRU order, populated from observers. Reads from cache; no AX calls.
    /// - Returns: An array of app dictionaries, each with name, pid, bundleID,
    ///   iconBase64, and windows: [{id, title}].
    /// - Example:
    /// ```js
    /// const snap = hs.window.snapshot()
    /// console.log(snap[0].name, snap[0].windows.length)
    /// ```
    @objc func snapshot() -> [[String: Any]]
```

- [ ] **Step 2: Add registry property and snapshot implementation**

In `HSWindowModule`, add inside the class (just after the `engineID` line):

```swift
    private lazy var registry: HSWindowRegistry = HSWindowRegistry()
```

And inside the API Implementation MARK section, add:

```swift
    @objc func snapshot() -> [[String: Any]] {
        return registry.snapshot().map { app in
            var dict: [String: Any] = [
                "pid": Int(app.pid),
                "name": app.name,
                "bundleID": app.bundleID as Any,
                "windows": app.windows.map { win in
                    [
                        "id": win.stableID,
                        "title": win.title,
                    ] as [String: Any]
                },
            ]
            if let icon = app.icon, let png = icon.pngData() {
                dict["iconBase64"] = png.base64EncodedString()
            }
            return dict
        }
    }

    /// Expose the registry to internal callers (e.g. `HSSwitcherSession`).
    func internalRegistry() -> HSWindowRegistry { registry }
```

- [ ] **Step 3: Add `pngData()` helper to NSImage**

If not already present, add this extension at the bottom of `HSWindowModule.swift`:

```swift
private extension NSImage {
    func pngData() -> Data? {
        guard let tiff = self.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .png, properties: [:])
    }
}
```

- [ ] **Step 4: Build**

```
xcodebuild build -target "Hammerspoon 2" -scheme "Development" -destination 'platform=macOS'
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 5: Add an integration test**

Append to `Hammerspoon 2Tests/IntegrationTests/HSWindowIntegrationTests.swift`:

```swift
    @Test("snapshot returns an array of app dicts with required keys")
    func testSnapshotShape() async {
        let h = await JSTestHarness()
        await h.loadModule(HSWindowModule.self, as: "window")
        // Give the registry a moment to seed (AX queries are async)
        try? await Task.sleep(nanoseconds: 500_000_000)
        let result = await h.eval("""
            const snap = hs.window.snapshot()
            JSON.stringify({
              isArray: Array.isArray(snap),
              len: snap.length,
              firstHasName: snap.length > 0 ? typeof snap[0].name === 'string' : true,
              firstHasPid: snap.length > 0 ? typeof snap[0].pid === 'number' : true,
              firstHasWindows: snap.length > 0 ? Array.isArray(snap[0].windows) : true,
            })
        """) as? String
        let json = result.flatMap { $0.data(using: .utf8) }
            .flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
        #expect(json?["isArray"] as? Bool == true)
        #expect(json?["firstHasName"] as? Bool == true)
        #expect(json?["firstHasPid"] as? Bool == true)
        #expect(json?["firstHasWindows"] as? Bool == true)
    }
```

- [ ] **Step 6: Run the test**

```
xcodebuild test -target "Hammerspoon 2" -scheme "Development" -destination 'platform=macOS' \
    -only-testing:Hammerspoon_2Tests/HSWindowIntegrationTests
```

Expected: PASS.

- [ ] **Step 7: Run docs pipeline**

```
cd /Users/jake/code/Hammerspoon2 && npm run docs:generate
```

- [ ] **Step 8: Commit**

```
git add "Hammerspoon 2/Modules/hs.window/HSWindowModule.swift" "Hammerspoon 2Tests/IntegrationTests/HSWindowIntegrationTests.swift" docs/api.json docs/hammerspoon.d.ts
git commit -m "feat(hs.window): expose snapshot() reading from live registry

Hot-path API for the switcher and any JS consumer that wants
MRU-ordered apps+windows without paying AX cost on every call."
```

---

# Phase 3 — `hs.switcher` (Swift-owned picker)

Goal: `hs.switcher.enable(cfg)` returns a session that handles ctrl×2, owns the eventtap, drives the picker state machine, and commits/cancels atomically.

## Task 3.1: Module skeleton + `enable()`/`disable()` shape

**Files:**
- Create: `Hammerspoon 2/Modules/hs.switcher/HSSwitcherModule.swift`
- Modify: `Hammerspoon 2/Engine/ModuleRoot.swift`

- [ ] **Step 1: Create the module**

Create `Hammerspoon 2/Modules/hs.switcher/HSSwitcherModule.swift`:

```swift
//
//  HSSwitcherModule.swift
//  Hammerspoon 2
//

import Foundation
import JavaScriptCore
import AppKit

/// `hs.switcher` — a cmd+Tab-replacement window/app switcher.
@objc protocol HSSwitcherModuleAPI: JSExport {
    /// Enable the switcher with the given configuration.
    /// - Parameter cfg: Object with optional keys:
    ///   - `commitDelayMs` (default 250) — ctrl-idle ms that triggers commit
    ///   - `filterPlaceholder` (default 'Type to filter…')
    ///   - `onCommit` (function, args: { appName, appPid, windowTitle, windowID })
    ///   - `onCancel` (function, no args)
    /// - Returns: `{ disable }` on success, `{ error }` on failure
    /// - Example:
    /// ```js
    /// const sw = hs.switcher.enable({ onCommit: e => console.log('->', e.appName) })
    /// // later: sw.disable()
    /// ```
    @objc func enable(_ cfg: JSValue) -> [String: Any]
}

@_documentation(visibility: private)
@MainActor
@objc class HSSwitcherModule: NSObject, HSModuleAPI, HSSwitcherModuleAPI {
    var name = "hs.switcher"
    let engineID: UUID
    private var activeBindings: [HSSwitcherBinding] = []

    required init(engineID: UUID) {
        self.engineID = engineID
        super.init()
        AKTrace("Init of \(name): \(engineID)")
    }

    func shutdown() {
        for b in activeBindings { b.disable() }
        activeBindings.removeAll()
    }

    isolated deinit {
        AKTrace("Deinit of \(name): \(engineID)")
    }

    @objc func enable(_ cfg: JSValue) -> [String: Any] {
        // Permission checks first — fail loudly with a structured error.
        guard AXIsProcessTrusted() else {
            return ["error": "accessibility"]
        }
        let config = HSSwitcherConfig(jsValue: cfg)
        let binding = HSSwitcherBinding(config: config)
        guard binding.install() else {
            return ["error": "inputMonitoring"]
        }
        activeBindings.append(binding)
        return [
            "disable": JSValue(object: { [weak self, weak binding] in
                binding?.disable()
                if let b = binding { self?.activeBindings.removeAll { $0 === b } }
            } as @convention(block) () -> Void, in: cfg.context) as Any,
        ]
    }
}

/// Per-`enable()` binding: owns the double-tap detector and creates a session
/// each time the user triggers the switcher.
@MainActor
final class HSSwitcherBinding {
    let config: HSSwitcherConfig
    private var doubleTapDetector: Any?    // reuses hs.hotkey's DoubleTapDetector
    private var activeSession: HSSwitcherSession?

    init(config: HSSwitcherConfig) {
        self.config = config
    }

    func install() -> Bool {
        // Implemented in Task 3.3 once HSSwitcherSession lands.
        return true
    }

    func disable() {
        activeSession?.cancel()
        activeSession = nil
        // Detach detector (Task 3.3)
    }
}

/// Parsed config; defaults applied here so the session never sees a missing field.
struct HSSwitcherConfig {
    let commitDelayMs: Int
    let filterPlaceholder: String
    let onCommit: JSValue?
    let onCancel: JSValue?

    init(jsValue: JSValue) {
        if jsValue.isObject {
            let v = jsValue.forProperty("commitDelayMs")
            commitDelayMs = (v?.isNumber == true) ? Int(v!.toInt32()) : 250
            let fp = jsValue.forProperty("filterPlaceholder")
            filterPlaceholder = (fp?.isString == true) ? (fp!.toString() ?? "Type to filter…") : "Type to filter…"
            let oc = jsValue.forProperty("onCommit")
            onCommit = (oc?.isObject == true && !(oc?.isNull ?? true)) ? oc : nil
            let on = jsValue.forProperty("onCancel")
            onCancel = (on?.isObject == true && !(on?.isNull ?? true)) ? on : nil
        } else {
            commitDelayMs = 250
            filterPlaceholder = "Type to filter…"
            onCommit = nil
            onCancel = nil
        }
    }
}
```

- [ ] **Step 2: Create a placeholder `HSSwitcherSession`**

Create `Hammerspoon 2/Modules/hs.switcher/HSSwitcherSession.swift`:

```swift
//
//  HSSwitcherSession.swift
//  Hammerspoon 2
//

import Foundation
import AppKit

@MainActor
final class HSSwitcherSession {
    private let config: HSSwitcherConfig

    init(config: HSSwitcherConfig) {
        self.config = config
    }

    func cancel() {
        // Filled in Task 3.8
    }
}
```

- [ ] **Step 3: Register the module in `ModuleRoot.swift`**

Edit `Hammerspoon 2/Engine/ModuleRoot.swift`:

In the protocol, after `@objc var sqlite: HSSqliteModule { get }`, add:
```swift
    @objc var switcher: HSSwitcherModule { get }
```

In the class, after the `sqlite` property, add:
```swift
    @objc var switcher: HSSwitcherModule { get { getOrCreate(name: "switcher", type: HSSwitcherModule.self)}}
```

- [ ] **Step 4: Build**

```
xcodebuild build -target "Hammerspoon 2" -scheme "Development" -destination 'platform=macOS'
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 5: Commit**

```
git add "Hammerspoon 2/Modules/hs.switcher/" "Hammerspoon 2/Engine/ModuleRoot.swift"
git commit -m "feat(hs.switcher): module skeleton + enable() API surface

Empty session for now; double-tap wiring and picker UI land in
subsequent tasks."
```

## Task 3.2: `HSSwitcherState` — `@Observable` picker state

**Files:**
- Create: `Hammerspoon 2/Modules/hs.switcher/HSSwitcherState.swift`

- [ ] **Step 1: Create the state class**

Create `Hammerspoon 2/Modules/hs.switcher/HSSwitcherState.swift`:

```swift
//
//  HSSwitcherState.swift
//  Hammerspoon 2
//

import Foundation
import Observation

@MainActor
@Observable
final class HSSwitcherState {
    enum Mode { case cycle, filter }

    /// Snapshot taken at session start. Frozen for the session's duration —
    /// changes to the registry after open don't reflow the picker.
    var apps: [HSAppEntry] = []

    /// Index into `apps`. -1 if no apps.
    var selectedAppIndex: Int = -1

    /// Index into `apps[selectedAppIndex].windows`. -1 if no windows.
    var selectedWindowIndex: Int = -1

    /// Cycle mode by default; filter mode entered on first non-cycle keystroke.
    var mode: Mode = .cycle

    /// Filter text. Empty in cycle mode; populated in filter mode.
    var filterText: String = ""

    /// Computed filtered view: in cycle mode, returns `apps` verbatim. In
    /// filter mode, returns apps that match (by name) or have at least one
    /// window matching by title.
    func filteredApps() -> [HSAppEntry] {
        guard mode == .filter, !filterText.isEmpty else { return apps }
        let needle = filterText.lowercased()
        return apps.filter { app in
            if app.name.lowercased().contains(needle) { return true }
            return app.windows.contains { $0.title.lowercased().contains(needle) }
        }
    }

    /// Move app selection forward (delta=+1) or back (delta=-1), wrapping.
    func moveAppSelection(by delta: Int) {
        let list = filteredApps()
        guard !list.isEmpty else { return }
        if selectedAppIndex < 0 { selectedAppIndex = 0; selectedWindowIndex = 0; return }
        let n = list.count
        let next = ((selectedAppIndex + delta) % n + n) % n
        selectedAppIndex = next
        selectedWindowIndex = list[next].windows.isEmpty ? -1 : 0
    }

    /// Move window selection within the highlighted app.
    func moveWindowSelection(by delta: Int) {
        let list = filteredApps()
        guard selectedAppIndex >= 0, selectedAppIndex < list.count else { return }
        let windows = list[selectedAppIndex].windows
        guard !windows.isEmpty else { return }
        let n = windows.count
        let next = ((selectedWindowIndex + delta) % n + n) % n
        selectedWindowIndex = next
    }

    /// Returns the currently-highlighted (app, window) pair, if any.
    func currentSelection() -> (HSAppEntry, HSWindowEntry?)? {
        let list = filteredApps()
        guard selectedAppIndex >= 0, selectedAppIndex < list.count else { return nil }
        let app = list[selectedAppIndex]
        if selectedWindowIndex < 0 || selectedWindowIndex >= app.windows.count {
            return (app, nil)
        }
        return (app, app.windows[selectedWindowIndex])
    }

    /// Apply default cmd+Tab-style selection: MRU[1] app's MRU[0] window.
    func applyDefaultSelection() {
        guard !apps.isEmpty else { return }
        if apps.count >= 2 {
            selectedAppIndex = 1
        } else {
            selectedAppIndex = 0
        }
        let windows = apps[selectedAppIndex].windows
        // Within the just-selected app: MRU[0] is current; we want "previous"
        // window when we only have one app, else just MRU[0].
        if apps.count < 2, windows.count >= 2 {
            selectedWindowIndex = 1
        } else {
            selectedWindowIndex = windows.isEmpty ? -1 : 0
        }
    }
}
```

- [ ] **Step 2: Build**

```
xcodebuild build -target "Hammerspoon 2" -scheme "Development" -destination 'platform=macOS'
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Write pure unit tests for the state machine**

Create `Hammerspoon 2Tests/UnitTests/HSSwitcherStateTests.swift`:

```swift
//
//  HSSwitcherStateTests.swift
//  Hammerspoon 2Tests
//

import Testing
@testable import Hammerspoon_2
import AppKit
import AXSwift

@MainActor
struct HSSwitcherStateTests {
    // Build a fake registry snapshot from given app names and per-app window titles
    private func makeApps(_ spec: [(String, [String])]) -> [HSAppEntry] {
        spec.enumerated().map { i, pair in
            let (name, titles) = pair
            // We can't easily make a real NSRunningApplication; HSAppEntry's init
            // takes one. For pure state tests we bypass by constructing minimally.
            let app = HSAppEntry(testOnlyName: name, pid: pid_t(1000 + i))
            app.windows = titles.enumerated().map { j, t in
                HSWindowEntry(stableID: UInt64(j + 1), axElement: TestUIElement(), title: t)
            }
            return app
        }
    }

    @Test("default selection points to MRU[1].MRU[0]")
    func testDefaultSelection() {
        let s = HSSwitcherState()
        s.apps = makeApps([
            ("Chrome", ["w1", "w2"]),
            ("Terminal", ["t1"]),
            ("Mail", ["m1"]),
        ])
        s.applyDefaultSelection()
        #expect(s.selectedAppIndex == 1)
        #expect(s.selectedWindowIndex == 0)
    }

    @Test("moveAppSelection wraps both directions")
    func testMoveAppWraps() {
        let s = HSSwitcherState()
        s.apps = makeApps([
            ("A", ["a1"]),
            ("B", ["b1"]),
            ("C", ["c1"]),
        ])
        s.selectedAppIndex = 0; s.selectedWindowIndex = 0
        s.moveAppSelection(by: 1); #expect(s.selectedAppIndex == 1)
        s.moveAppSelection(by: 1); #expect(s.selectedAppIndex == 2)
        s.moveAppSelection(by: 1); #expect(s.selectedAppIndex == 0)
        s.moveAppSelection(by: -1); #expect(s.selectedAppIndex == 2)
    }

    @Test("filter narrows the visible apps")
    func testFilter() {
        let s = HSSwitcherState()
        s.apps = makeApps([
            ("Chrome", ["github", "gmail"]),
            ("Terminal", ["ssh"]),
            ("Mail", ["inbox"]),
        ])
        s.mode = .filter
        s.filterText = "mail"
        let visible = s.filteredApps().map { $0.name }
        #expect(visible.contains("Chrome"))   // window title "gmail" matches
        #expect(visible.contains("Mail"))     // app name matches
        #expect(!visible.contains("Terminal"))
    }
}

/// Tiny stub to construct HSWindowEntry without a real AXUIElement.
private final class TestUIElement: AXSwift.UIElement {
    init() {
        // AXSwift.UIElement requires an AXUIElement — use the system-wide one
        // as a harmless stand-in for tests that don't actually exercise AX.
        super.init(AXUIElementCreateSystemWide())
    }
}
```

- [ ] **Step 4: Add a test-only convenience initializer to `HSAppEntry`**

In `Hammerspoon 2/Modules/hs.window/HSAppEntry.swift`, append inside the class:

```swift
    #if DEBUG
    /// Test-only init for state-machine unit tests that don't need a real
    /// NSRunningApplication.
    init(testOnlyName: String, pid: pid_t) {
        self.pid = pid
        self.name = testOnlyName
        self.bundleID = nil
        self.icon = nil
        self.windows = []
        self.lastActivatedAt = Date()
        self.observer = nil
        self.pollTimer = nil
    }
    #endif
```

- [ ] **Step 5: Make sure the UnitTests folder exists, then run the new tests**

```
mkdir -p "Hammerspoon 2Tests/UnitTests"
```

Then add `HSSwitcherStateTests.swift` to the test target in Xcode (the .pbxproj will need updating). For a Swift Package Manager-style auto-discovery project this is automatic; for an Xcode project, this requires manual addition.

If the project auto-discovers tests by file location, run:
```
xcodebuild test -target "Hammerspoon 2" -scheme "Development" -destination 'platform=macOS' \
    -only-testing:Hammerspoon_2Tests/HSSwitcherStateTests
```

Expected: PASS. If file isn't picked up: open the project in Xcode and add it to the test target (this is a one-time manual step).

- [ ] **Step 6: Commit**

```
git add "Hammerspoon 2/Modules/hs.switcher/HSSwitcherState.swift" "Hammerspoon 2/Modules/hs.window/HSAppEntry.swift" "Hammerspoon 2Tests/UnitTests/HSSwitcherStateTests.swift"
git commit -m "feat(hs.switcher): @Observable picker state with filter/cycle modes

Pure state-machine class — no AX, no UI. Default selection matches
cmd+Tab (MRU[1].MRU[0]); filter narrows by app name or window title."
```

## Task 3.3: Wire double-tap trigger to session creation

**Files:**
- Modify: `Hammerspoon 2/Modules/hs.switcher/HSSwitcherModule.swift`
- Modify: `Hammerspoon 2/Modules/hs.switcher/HSSwitcherSession.swift`

- [ ] **Step 1: Make `DoubleTapDetector` from hs.hotkey reusable**

Edit `Hammerspoon 2/Modules/hs.hotkey/HSHotkeyModule.swift`. Find the `private final class DoubleTapDetector` declaration (around line 106) and change `private` → `internal`. Also change the `init(modifier:callback:)` to accept a generic completion closure rather than a `JSValue`:

Add (don't replace) a new initializer alongside the existing one:

```swift
    init(modifier: NSEvent.ModifierFlags, swiftCallback: @escaping () -> Void) {
        self.modifierMask = modifier
        // We don't have a JSValue; store nil and use the swift closure path
        self.callback = JSValue()   // never invoked; isolated to filter branch
        self.swiftCallback = swiftCallback
    }
```

Add a stored property near the existing `callback`:
```swift
    private let swiftCallback: (() -> Void)?
```

And change the existing `init(modifier:callback:)` to set `self.swiftCallback = nil`.

Then modify the firing branch (`case 3: if allUp { ... }`) to choose:

```swift
        case 3:
            if allUp {
                if let swift = swiftCallback {
                    DispatchQueue.main.async { swift() }
                } else {
                    let cb = self.callback
                    DispatchQueue.main.async { cb.callSafely(withArguments: [], context: "hs.hotkey doubletap") }
                }
                state = 0; firstReleaseAt = nil
            } else if !isOurModDown {
                state = 0; firstReleaseAt = nil
            }
```

- [ ] **Step 2: Implement `HSSwitcherBinding.install` and `disable`**

Edit `HSSwitcherModule.swift`. Replace the `HSSwitcherBinding` class with:

```swift
@MainActor
final class HSSwitcherBinding {
    let config: HSSwitcherConfig
    private var detector: DoubleTapDetector?
    private var activeSession: HSSwitcherSession?

    init(config: HSSwitcherConfig) {
        self.config = config
    }

    func install() -> Bool {
        let det = DoubleTapDetector(modifier: .control, swiftCallback: { [weak self] in
            self?.onTrigger()
        })
        det.start()
        self.detector = det
        return true
    }

    func disable() {
        activeSession?.cancel()
        activeSession = nil
        detector?.stop()
        detector = nil
    }

    private func onTrigger() {
        // If a session is already active, ignore re-triggers.
        if activeSession != nil { return }
        let session = HSSwitcherSession(config: config) { [weak self] in
            self?.activeSession = nil
        }
        // Reading the snapshot is the only synchronous AX-adjacent work we do
        // here. It's reading from cache, not querying AX, so it's fast.
        guard let registry = ModuleRoot.currentWindowRegistry() else { return }
        session.start(snapshot: registry.snapshot())
        activeSession = session
    }
}
```

- [ ] **Step 3: Add a static accessor to find the window registry**

Edit `Hammerspoon 2/Engine/ModuleRoot.swift`. Add inside the `ModuleRoot` class:

```swift
    /// Get the live window registry for the engine that owns the current main-thread JSContext.
    /// Used by other modules (e.g. `hs.switcher`) to share state.
    @MainActor
    static func currentWindowRegistry() -> HSWindowRegistry? {
        // The window module is created lazily; force it now if not yet present
        // by going through the public accessor.
        guard let ctx = JSEngine.shared.context,
              let hsObj = ctx.objectForKeyedSubscript("hs"),
              let root = hsObj.toObject() as? ModuleRoot else { return nil }
        return root.window.internalRegistry()
    }
```

If `JSEngine.shared.context` doesn't exist with that exact shape, look at how `HSConsoleModule` or `ManagerManager` accesses the JS context and follow the same pattern.

- [ ] **Step 4: Make `HSSwitcherSession.start(snapshot:)` placeholder**

Edit `HSSwitcherSession.swift`. Replace the class body with:

```swift
@MainActor
final class HSSwitcherSession {
    private let config: HSSwitcherConfig
    private let onClose: () -> Void
    let state = HSSwitcherState()
    private var isClosed = false

    init(config: HSSwitcherConfig, onClose: @escaping () -> Void) {
        self.config = config
        self.onClose = onClose
    }

    func start(snapshot: [HSAppEntry]) {
        state.apps = snapshot
        state.applyDefaultSelection()
        // UI + eventtap installation lands in Task 3.4/3.7
        AKTrace("HSSwitcherSession.start with \(snapshot.count) apps")
    }

    func cancel() {
        guard !isClosed else { return }
        isClosed = true
        // Tear down UI + eventtap (Task 3.8)
        onClose()
        config.onCancel?.callSafely(withArguments: [], context: "hs.switcher onCancel")
    }
}
```

- [ ] **Step 5: Build**

```
xcodebuild build -target "Hammerspoon 2" -scheme "Development" -destination 'platform=macOS'
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 6: Commit**

```
git add "Hammerspoon 2/Modules/hs.hotkey/HSHotkeyModule.swift" "Hammerspoon 2/Modules/hs.switcher/" "Hammerspoon 2/Engine/ModuleRoot.swift"
git commit -m "feat(hs.switcher): bind ctrl×2 trigger to session creation

Reuses DoubleTapDetector from hs.hotkey via a swift-callback overload.
Sessions read snapshots from the shared HSWindowRegistry. UI/eventtap
installation lands in subsequent tasks."
```

## Task 3.4: Eventtap with key-handling discipline

**Files:**
- Create: `Hammerspoon 2/Modules/hs.switcher/HSSwitcherKeyHandler.swift`
- Modify: `Hammerspoon 2/Modules/hs.switcher/HSSwitcherSession.swift`

- [ ] **Step 1: Create the key handler**

Create `Hammerspoon 2/Modules/hs.switcher/HSSwitcherKeyHandler.swift`:

```swift
//
//  HSSwitcherKeyHandler.swift
//  Hammerspoon 2
//

import Foundation
import AppKit
import Carbon.HIToolbox

/// Routes CGEventTap callbacks into session intent. Lives for the duration of
/// one session; tears down on stop().
@MainActor
final class HSSwitcherKeyHandler {
    /// Intents the session can respond to.
    enum Intent {
        case nextApp
        case prevApp
        case nextWindow
        case prevWindow
        case commit            // ctrl idle long enough
        case cancel
        case enterFilter(String)
        case filterAppend(String)
        case filterBackspace
    }

    private let onIntent: (Intent) -> Void
    private let commitDelay: TimeInterval
    private weak var stateRef: HSSwitcherState?

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var commitTimer: Timer?
    private var ctrlHeld = false

    init(state: HSSwitcherState, commitDelayMs: Int, onIntent: @escaping (Intent) -> Void) {
        self.onIntent = onIntent
        self.commitDelay = Double(commitDelayMs) / 1000.0
        self.stateRef = state
        // ctrl is presumed held at session creation (we just got triggered by ctrl×2
        // and the second ctrl-down is what fires us).
        self.ctrlHeld = true
        armCommitTimer()
    }

    func install() -> Bool {
        let mask: CGEventMask =
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.flagsChanged.rawValue)
        let opaqueSelf = Unmanaged.passUnretained(self).toOpaque()
        let cb: CGEventTapCallBack = { _, type, cgEvent, refcon in
            guard let refcon else { return Unmanaged.passUnretained(cgEvent) }
            let me = Unmanaged<HSSwitcherKeyHandler>.fromOpaque(refcon).takeUnretainedValue()
            return me.handle(type: type, event: cgEvent)
        }
        guard let t = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: cb,
            userInfo: opaqueSelf
        ) else {
            AKError("HSSwitcherKeyHandler: CGEvent.tapCreate failed — Input Monitoring permission missing?")
            return false
        }
        self.tap = t
        let src = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, t, 0)
        self.runLoopSource = src
        CFRunLoopAddSource(CFRunLoopGetMain(), src, .commonModes)
        CGEvent.tapEnable(tap: t, enable: true)
        return true
    }

    func stop() {
        commitTimer?.invalidate(); commitTimer = nil
        if let t = tap {
            CGEvent.tapEnable(tap: t, enable: false)
            if let s = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetMain(), s, .commonModes)
            }
            tap = nil
            runLoopSource = nil
        }
    }

    // MARK: - Event handling

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // OS may disable a tap that exceeds its timeout; re-enable if so.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let t = tap { CGEvent.tapEnable(tap: t, enable: true) }
            return Unmanaged.passUnretained(event)
        }

        let state = stateRef?.mode ?? .cycle

        if type == .flagsChanged {
            return handleFlags(event: event, mode: state)
        }
        if type == .keyDown {
            return handleKeyDown(event: event, mode: state)
        }
        return Unmanaged.passUnretained(event)
    }

    private func handleFlags(event: CGEvent, mode: HSSwitcherState.Mode) -> Unmanaged<CGEvent>? {
        let flags = event.flags
        let nowCtrl = flags.contains(.maskControl)
        if nowCtrl && !ctrlHeld {
            // ctrl just pressed: reset commit timer
            ctrlHeld = true
            commitTimer?.invalidate()
        } else if !nowCtrl && ctrlHeld {
            // ctrl just released: in cycle mode, arm commit; in filter mode, ignore.
            ctrlHeld = false
            if mode == .cycle {
                armCommitTimer()
            }
        }
        return Unmanaged.passUnretained(event)   // never consume flag-changes
    }

    private func handleKeyDown(event: CGEvent, mode: HSSwitcherState.Mode) -> Unmanaged<CGEvent>? {
        let keyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags
        let hasShift = flags.contains(.maskShift)
        let onlyCtrlAndMaybeShift =
            flags.subtracting([.maskControl, .maskShift, .maskAlphaShift, .maskNumericPad, .maskSecondaryFn]).isEmpty

        // Universal: escape cancels in either mode
        if keyCode == kVK_Escape {
            onIntent(.cancel)
            return nil
        }
        // Arrow keys: navigate
        switch keyCode {
        case kVK_LeftArrow:  onIntent(.prevApp); return nil
        case kVK_RightArrow: onIntent(.nextApp); return nil
        case kVK_UpArrow:    onIntent(.prevWindow); return nil
        case kVK_DownArrow:  onIntent(.nextWindow); return nil
        default: break
        }

        // Cycle mode
        if mode == .cycle {
            // ctrl-tab equivalent: any keyDown while ctrl is held with no other
            // mods is treated as "next app" (or prev if shift). This is what
            // makes the cycling muscle-memory work when the user taps a key
            // while ctrl is held; the canonical trigger here is keyCode == kVK_Tab
            // but we accept any non-character key to be lenient.
            if onlyCtrlAndMaybeShift && keyCode == kVK_Tab {
                onIntent(hasShift ? .prevApp : .nextApp)
                return nil
            }
            // Enter commits the current selection
            if keyCode == kVK_Return || keyCode == kVK_ANSI_KeypadEnter {
                onIntent(.commit)
                return nil
            }
            // Plain ASCII letter/digit with no modifiers → enter filter mode
            if let s = unicodeCharacter(event: event),
               s.count == 1,
               let scalar = s.unicodeScalars.first,
               flags.intersection([.maskCommand, .maskAlternate, .maskControl]).isEmpty,
               (scalar.isASCII && (CharacterSet.alphanumerics.contains(scalar) || scalar == " ")) {
                onIntent(.enterFilter(s))
                return nil
            }
            // Everything else: pass through
            return Unmanaged.passUnretained(event)
        }

        // Filter mode — we own the keyboard
        if keyCode == kVK_Delete {
            onIntent(.filterBackspace)
            return nil
        }
        if keyCode == kVK_Return || keyCode == kVK_ANSI_KeypadEnter {
            onIntent(.commit)
            return nil
        }
        if let s = unicodeCharacter(event: event), !s.isEmpty {
            onIntent(.filterAppend(s))
            return nil
        }
        return nil   // consume everything in filter mode
    }

    private func unicodeCharacter(event: CGEvent) -> String? {
        var actualLen = 0
        var buf = [UniChar](repeating: 0, count: 4)
        event.keyboardGetUnicodeString(maxStringLength: 4, actualStringLength: &actualLen, unicodeString: &buf)
        guard actualLen > 0 else { return nil }
        return String(utf16CodeUnits: buf, count: actualLen)
    }

    // MARK: - Commit timer

    private func armCommitTimer() {
        commitTimer?.invalidate()
        commitTimer = Timer.scheduledTimer(withTimeInterval: commitDelay, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                if !self.ctrlHeld {
                    self.onIntent(.commit)
                }
            }
        }
    }
}
```

- [ ] **Step 2: Wire the key handler into `HSSwitcherSession`**

In `HSSwitcherSession.swift`, replace the body with:

```swift
@MainActor
final class HSSwitcherSession {
    private let config: HSSwitcherConfig
    private let onClose: () -> Void
    let state = HSSwitcherState()
    private var keyHandler: HSSwitcherKeyHandler?
    private var safetyTimer: Timer?
    private var isClosed = false

    init(config: HSSwitcherConfig, onClose: @escaping () -> Void) {
        self.config = config
        self.onClose = onClose
    }

    func start(snapshot: [HSAppEntry]) -> Bool {
        state.apps = snapshot
        state.applyDefaultSelection()
        guard !state.apps.isEmpty else { onClose(); return false }

        let handler = HSSwitcherKeyHandler(
            state: state,
            commitDelayMs: config.commitDelayMs
        ) { [weak self] intent in
            self?.handle(intent: intent)
        }
        guard handler.install() else { onClose(); return false }
        self.keyHandler = handler

        safetyTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.cancel() }
        }

        // UI shows in Task 3.7
        return true
    }

    private func handle(intent: HSSwitcherKeyHandler.Intent) {
        switch intent {
        case .nextApp:     state.moveAppSelection(by: 1)
        case .prevApp:     state.moveAppSelection(by: -1)
        case .nextWindow:  state.moveWindowSelection(by: 1)
        case .prevWindow:  state.moveWindowSelection(by: -1)
        case .commit:      commit()
        case .cancel:      cancel()
        case .enterFilter(let s):
            state.mode = .filter
            state.filterText = s
        case .filterAppend(let s):
            state.filterText += s
        case .filterBackspace:
            if !state.filterText.isEmpty {
                state.filterText.removeLast()
                if state.filterText.isEmpty { state.mode = .cycle }
            }
        }
    }

    func commit() {
        guard !isClosed else { return }
        guard let (app, window) = state.currentSelection() else { cancel(); return }
        tearDown()
        focus(app: app, window: window)
        if let cb = config.onCommit {
            let payload: [String: Any] = [
                "appName": app.name,
                "appPid": Int(app.pid),
                "windowTitle": window?.title as Any,
                "windowID": window?.stableID as Any,
            ]
            cb.callSafely(withArguments: [payload], context: "hs.switcher onCommit")
        }
        onClose()
    }

    func cancel() {
        guard !isClosed else { return }
        tearDown()
        config.onCancel?.callSafely(withArguments: [], context: "hs.switcher onCancel")
        onClose()
    }

    private func tearDown() {
        isClosed = true
        keyHandler?.stop()
        keyHandler = nil
        safetyTimer?.invalidate()
        safetyTimer = nil
        // UI teardown in Task 3.7
    }

    private func focus(app: HSAppEntry, window: HSWindowEntry?) {
        if let win = window {
            AXUIElementSetMessagingTimeout(win.axElement.element, 0.1)
            try? win.axElement.performAction(.raise)
        }
        if let runningApp = NSRunningApplication(processIdentifier: app.pid) {
            runningApp.activate(options: [])
        }
    }
}
```

- [ ] **Step 3: Build**

```
xcodebuild build -target "Hammerspoon 2" -scheme "Development" -destination 'platform=macOS'
```

Expected: BUILD SUCCEEDED. If you get an error about `kVK_*` constants not being found, add `import Carbon.HIToolbox` to `HSSwitcherKeyHandler.swift` (already in the file above).

- [ ] **Step 4: Commit**

```
git add "Hammerspoon 2/Modules/hs.switcher/HSSwitcherKeyHandler.swift" "Hammerspoon 2/Modules/hs.switcher/HSSwitcherSession.swift"
git commit -m "feat(hs.switcher): eventtap with key-pass-through discipline

Hot path stays in Swift: cycle-mode passes through unhandled keys;
filter-mode owns the keyboard. Commit fires after ctrl idle for the
configured delay. Safety timer guards against stuck sessions."
```

## Task 3.5: SwiftUI picker view

**Files:**
- Create: `Hammerspoon 2/Modules/hs.switcher/HSSwitcherView.swift`
- Modify: `Hammerspoon 2/Modules/hs.switcher/HSSwitcherSession.swift`

- [ ] **Step 1: Create the view**

Create `Hammerspoon 2/Modules/hs.switcher/HSSwitcherView.swift`:

```swift
//
//  HSSwitcherView.swift
//  Hammerspoon 2
//

import SwiftUI
import AppKit

struct HSSwitcherView: View {
    @Bindable var state: HSSwitcherState
    let placeholder: String

    var body: some View {
        let apps = state.filteredApps()
        VStack(alignment: .leading, spacing: 0) {
            if state.mode == .filter || !state.filterText.isEmpty {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    Text(state.filterText.isEmpty ? placeholder : state.filterText)
                        .foregroundColor(state.filterText.isEmpty ? .secondary : .primary)
                        .font(.system(size: 16, weight: .medium))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                Divider()
            }
            if apps.isEmpty {
                Text("No matches")
                    .foregroundColor(.secondary)
                    .padding(20)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(apps.enumerated()), id: \.offset) { appIdx, app in
                            appHeader(app, idx: appIdx)
                            ForEach(Array(app.windows.enumerated()), id: \.element.stableID) { winIdx, win in
                                windowRow(app: app, win: win, appIdx: appIdx, winIdx: winIdx)
                            }
                        }
                    }
                }
                .frame(maxHeight: 480)
            }
        }
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(radius: 24)
    }

    @ViewBuilder
    private func appHeader(_ app: HSAppEntry, idx: Int) -> some View {
        let isSelectedApp = (idx == state.selectedAppIndex)
        HStack(spacing: 8) {
            if let icon = app.icon {
                Image(nsImage: icon).resizable().frame(width: 24, height: 24)
            }
            Text(app.name)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(isSelectedApp && app.windows.isEmpty ? .white : .primary)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isSelectedApp && app.windows.isEmpty ? Color.accentColor : Color.clear)
    }

    @ViewBuilder
    private func windowRow(app: HSAppEntry, win: HSWindowEntry, appIdx: Int, winIdx: Int) -> some View {
        let isSelected = (appIdx == state.selectedAppIndex) && (winIdx == state.selectedWindowIndex)
        HStack(spacing: 8) {
            Spacer().frame(width: 32)
            Text(win.title.isEmpty ? "(untitled)" : win.title)
                .font(.system(size: 13))
                .foregroundColor(isSelected ? .white : .primary)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(isSelected ? Color.accentColor : Color.clear)
        .contentShape(Rectangle())
    }
}
```

- [ ] **Step 2: Show the view from the session via a borderless NSWindow**

In `HSSwitcherSession.swift`, add at the top: `import SwiftUI` and `import AppKit`. Add a property: `private var window: NSWindow?`.

In `start(snapshot:)`, after `state.applyDefaultSelection()` and the empty-snapshot guard, insert:

```swift
        let view = HSSwitcherView(state: state, placeholder: config.filterPlaceholder)
        let hosting = NSHostingController(rootView: view)
        let win = HSSwitcherPanel(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 400),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        win.contentViewController = hosting
        win.isOpaque = false
        win.backgroundColor = .clear
        win.level = .modalPanel
        win.hasShadow = true
        win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        if let screen = NSScreen.main {
            let f = screen.frame
            let w = win.frame.width, h = win.frame.height
            win.setFrame(NSRect(x: f.midX - w/2, y: f.midY - h/2, width: w, height: h), display: false)
        }
        win.makeKeyAndOrderFront(nil)
        // Cancel on focus loss (user cmd-tabbed away)
        NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: win, queue: .main
        ) { [weak self] _ in MainActor.assumeIsolated { self?.cancel() } }
        self.window = win
```

In `tearDown()`, after the safety timer invalidation, add:
```swift
        window?.orderOut(nil)
        window = nil
```

- [ ] **Step 3: Define the panel subclass that can become key without activating**

At the bottom of `HSSwitcherSession.swift`, add:

```swift
/// Panel that can become key without activating Hammerspoon as the foreground
/// app. Necessary so the picker can receive mouse events (clicks for commit)
/// without stealing focus from whatever app the user came from.
final class HSSwitcherPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
```

- [ ] **Step 4: Build**

```
xcodebuild build -target "Hammerspoon 2" -scheme "Development" -destination 'platform=macOS'
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 5: Commit**

```
git add "Hammerspoon 2/Modules/hs.switcher/HSSwitcherView.swift" "Hammerspoon 2/Modules/hs.switcher/HSSwitcherSession.swift"
git commit -m "feat(hs.switcher): SwiftUI picker view + non-activating panel

LazyVStack so a hundred windows doesn't instantiate a hundred row
views. Per-row @Observable means only the changed rows re-render on
selection moves."
```

## Task 3.6: Mouse click on row commits selection

**Files:**
- Modify: `Hammerspoon 2/Modules/hs.switcher/HSSwitcherView.swift`

- [ ] **Step 1: Add a click handler to row rendering**

In `HSSwitcherView.swift`, modify both `appHeader` and `windowRow` to accept a click callback. Replace the existing view body's `ForEach` with versions that pass a click handler:

Change the signature of `HSSwitcherView` to accept an `onPick: (Int, Int) -> Void`:

```swift
struct HSSwitcherView: View {
    @Bindable var state: HSSwitcherState
    let placeholder: String
    let onPick: (_ appIdx: Int, _ windowIdx: Int) -> Void
    // ...
```

In `appHeader` add `.onTapGesture { onPick(idx, -1) }` to the HStack.
In `windowRow` add `.onTapGesture { onPick(appIdx, winIdx) }` to the HStack.

- [ ] **Step 2: Wire `onPick` from the session**

In `HSSwitcherSession.swift`, where you construct the view:

```swift
        let view = HSSwitcherView(state: state, placeholder: config.filterPlaceholder) { [weak self] appIdx, winIdx in
            guard let self else { return }
            self.state.selectedAppIndex = appIdx
            self.state.selectedWindowIndex = winIdx
            self.commit()
        }
```

- [ ] **Step 3: Build, commit**

```
xcodebuild build -target "Hammerspoon 2" -scheme "Development" -destination 'platform=macOS'
git add "Hammerspoon 2/Modules/hs.switcher/HSSwitcherView.swift" "Hammerspoon 2/Modules/hs.switcher/HSSwitcherSession.swift"
git commit -m "feat(hs.switcher): mouse click on row commits selection"
```

## Task 3.7: Integration tests for the JS API surface

**Files:**
- Create: `Hammerspoon 2Tests/IntegrationTests/HSSwitcherTests.swift`

- [ ] **Step 1: Add tests for the structural contract of `enable()`**

Create `Hammerspoon 2Tests/IntegrationTests/HSSwitcherTests.swift`:

```swift
//
//  HSSwitcherTests.swift
//  Hammerspoon 2Tests
//

import Testing
@testable import Hammerspoon_2

@MainActor
struct HSSwitcherTests {
    @Test("enable returns a disable function or an error object")
    func testEnableShape() async {
        let h = await JSTestHarness()
        await h.loadModule(HSSwitcherModule.self, as: "switcher")
        let result = await h.eval("""
            const r = hs.switcher.enable({})
            JSON.stringify({
              hasDisable: typeof r.disable === 'function',
              hasError: typeof r.error === 'string',
            })
        """) as? String
        let json = result.flatMap { $0.data(using: .utf8) }
            .flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
        // Must be exactly one of: disable fn OR error string. Both is a bug.
        let hasDisable = (json?["hasDisable"] as? Bool) ?? false
        let hasError = (json?["hasError"] as? Bool) ?? false
        #expect(hasDisable != hasError)
    }

    @Test("disable() on returned session does not throw")
    func testDisable() async {
        let h = await JSTestHarness()
        await h.loadModule(HSSwitcherModule.self, as: "switcher")
        _ = await h.eval("""
            const r = hs.switcher.enable({})
            if (typeof r.disable === 'function') r.disable()
        """)
        #expect(await h.hasException == false)
    }

    @Test("invalid config still returns a structured response")
    func testRobustToBadConfig() async {
        let h = await JSTestHarness()
        await h.loadModule(HSSwitcherModule.self, as: "switcher")
        let result = await h.eval("""
            const r = hs.switcher.enable("not an object")
            typeof r === 'object'
        """)
        #expect(result as? Bool == true)
    }
}
```

- [ ] **Step 2: Run the tests**

```
xcodebuild test -target "Hammerspoon 2" -scheme "Development" -destination 'platform=macOS' \
    -only-testing:Hammerspoon_2Tests/HSSwitcherTests
```

Expected: PASS for `testEnableShape`, `testDisable`, `testRobustToBadConfig`. On a CI host without Accessibility/Input Monitoring granted, `enable()` will return `{ error: 'accessibility' }` — that's still passing the contract test.

- [ ] **Step 3: Run docs pipeline**

```
cd /Users/jake/code/Hammerspoon2 && npm run docs:generate
```

- [ ] **Step 4: Commit**

```
git add "Hammerspoon 2Tests/IntegrationTests/HSSwitcherTests.swift" docs/api.json docs/hammerspoon.d.ts
git commit -m "test(hs.switcher): contract tests for enable()/disable()"
```

---

# Phase 4 — Vibecast Migration + Manual Verification

Goal: replace vibecast's switcher with `hs.switcher.enable()`. Verify by actually using the app.

## Task 4.1: Replace vibecast switcher integration

**Files:**
- Modify: `/Users/jake/code/vibecast/features/windows/index.js`
- Delete: `/Users/jake/code/vibecast/features/windows/switcher.js`

- [ ] **Step 1: Update `index.js`**

In `/Users/jake/code/vibecast/features/windows/index.js`, remove the `const { openSwitcher } = require('./switcher')` line. Remove the `ctrlHotkey = hs.hotkey?.bindDoubleTap?.('ctrl', () => openSwitcher())` block and the corresponding teardown. Replace with:

```js
  // ctrl×2 → built-in production switcher (Swift-driven, observer-backed cache)
  const result = hs.switcher?.enable?.({
    commitDelayMs: 250,
    filterPlaceholder: 'Filter windows…',
    onCommit: (entry) => {
      // Optional: keep a debug log
      try { console.log('[vibecast] switcher commit:', entry.appName, entry.windowTitle || '') } catch (_) {}
    },
    onCancel: () => {},
  })
  if (result?.error) {
    try { console.warn('[vibecast] switcher unavailable:', result.error) } catch (_) {}
  } else if (typeof result?.disable === 'function') {
    teardowns.push(() => { try { result.disable() } catch (_) {} })
  }
```

- [ ] **Step 2: Delete the old switcher.js**

```
rm /Users/jake/code/vibecast/features/windows/switcher.js
```

Also remove any reference to it in the test directory if present:
```
ls /Users/jake/code/vibecast/tests/unit/features/windows/ 2>/dev/null
```

If `switcher.test.js` exists, delete it too:
```
rm /Users/jake/code/vibecast/tests/unit/features/windows/switcher.test.js 2>/dev/null
```

- [ ] **Step 3: Update the existing index.test.js if it imports `./switcher`**

Look for `require('./switcher')` in `/Users/jake/code/vibecast/tests/unit/features/windows/index.test.js` and remove if present. If the test calls `openSwitcher` directly, the corresponding test sections need to be deleted.

- [ ] **Step 4: Commit (in vibecast repo)**

```
cd /Users/jake/code/vibecast
git add -A features/windows tests/unit/features/windows
git commit -m "feat(windows): swap custom switcher for built-in hs.switcher

Production switcher lives in HS2 now — observer-backed MRU cache,
Swift-owned eventtap, bounded AX calls. Custom JS switcher deleted."
```

## Task 4.2: Manual verification checklist

These cannot be automated (require real keyboard, real apps, real Accessibility/Input-Monitoring permissions). Run through them in order.

- [ ] **Step 1: Build the latest Hammerspoon 2 and launch it**

```
cd /Users/jake/code/Hammerspoon2
xcodebuild build -target "Hammerspoon 2" -scheme "Development" -destination 'platform=macOS'
```

Then in Xcode press ⌘R to launch, OR find the built `.app` in `build/Build/Products/Development/` and double-click.

- [ ] **Step 2: Verify ctrl×2 opens the picker**

With several apps open (Chrome, Terminal, Finder, etc.), double-tap ctrl. Picker should appear in < 100 ms.

✅ Pass: picker visible with > 1 app, MRU[1].MRU[0] highlighted
❌ Fail: no picker, error in console — check Accessibility + Input Monitoring permissions

- [ ] **Step 3: Verify cycling**

With picker open, tap ctrl again (without typing). Selection should advance to MRU[2]. Tap shift+ctrl — should go back. Tap arrow keys — down/up moves within app's windows; left/right moves between apps.

✅ Pass: every keystroke moves the highlight within one frame
❌ Fail: lag, no highlight movement, wrong direction — check event handler

- [ ] **Step 4: Verify commit**

With a window highlighted, release ctrl and wait ~300 ms. Picker should dismiss; highlighted window should be focused.

✅ Pass: instant focus, picker gone
❌ Fail: picker lingers, wrong window focused

- [ ] **Step 5: Verify Escape cancels**

Open picker, press Escape. Picker dismisses; previously-focused app stays focused.

- [ ] **Step 6: Verify type-to-filter**

Open picker, type a few letters. Filter header appears. List narrows. Press Enter to commit; press Escape to cancel; press Backspace to edit; empty filter returns to cycle mode.

- [ ] **Step 7: Verify AX-hostile app doesn't freeze**

Find or simulate an unresponsive app (Preview hung on a PDF often works). Open picker. Should still open instantly even though Preview's AX is broken — Preview will appear with whatever windows the registry already cached, or no windows if none were ever observed. Either way: no freeze.

- [ ] **Step 8: Verify safety timeout**

Open picker, walk away for 20 s, don't touch keyboard. Picker should auto-dismiss at 15 s.

- [ ] **Step 9: Verify focus loss cancels**

Open picker, cmd-tab to another app (don't release cmd until you've switched). Picker should cancel; new app should be focused normally.

- [ ] **Step 10: Document results**

For each step that failed, file a follow-up. For each that passed, you're done.

- [ ] **Step 11: Commit any final fixes**

If verification revealed bugs, fix them now with the same TDD discipline (failing test → fix → passing test → commit).

---

## Self-Review

After completing all tasks, verify against the spec:

- [ ] **Performance budgets (spec §4)**: Did manual verification confirm picker < 30 ms, ctrl-tap < 8 ms, filter < 16 ms? If you timed any of these and they were over budget, file a follow-up.
- [ ] **All failure modes (spec §6)** handled: AX timeout, AXObserver fail, AX-hostile app, missing permissions, focus loss, eventtap disabled, safety timer. Walk the table; every row should map to code.
- [ ] **API surface (spec §5.4)**: `hs.switcher.enable({ commitDelayMs, filterPlaceholder, onCommit, onCancel })` returning `{ disable }` or `{ error }`. Confirm against `HSSwitcherModule.enable()`.
- [ ] **Existing `hs.window.*` APIs**: still work, with new bounded timeout protection.
- [ ] **No new docs warnings**: `npm run docs:generate` runs clean.
