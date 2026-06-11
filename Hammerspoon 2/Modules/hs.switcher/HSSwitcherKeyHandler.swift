//
//  HSSwitcherKeyHandler.swift
//  Hammerspoon 2
//

import Foundation
import AppKit
import Carbon.HIToolbox

/// Owns the `CGEventTap` for one switcher session. The hot path stays in
/// Swift — no JS round-trip per keystroke. Translates keyboard events into
/// higher-level `Intent`s for the session to act on.
///
/// Key-handling discipline:
/// - Cycle mode: consumes only ctrl-tab (cycle), arrows, Escape, Enter, and
///   plain ASCII letter/digit (mode-entry trigger). Everything else passes
///   through to the focused app.
/// - Filter mode: consumes all `keyDown` — we own the keyboard.
@MainActor
final class HSSwitcherKeyHandler {
    enum Intent {
        case nextApp
        case prevApp
        case nextRow      // ↓ — next row of the flat list (crosses app boundaries)
        case prevRow      // ↑
        case commit
        case cancel
        case enterFilter(String)
        case filterAppend(String)
        case filterBackspace
    }

    private let onIntent: (Intent) -> Void
    private let commitDelay: TimeInterval

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var commitTimer: Timer?
    private var ctrlHeld = true   // session starts on second ctrl-down

    /// Filter mode is determined by the session via callbacks. The handler
    /// keeps a local mirror so it can decide pass-through vs consume without
    /// a round-trip per keystroke.
    private(set) var modeIsFilter: Bool = false

    init(commitDelayMs: Int, onIntent: @escaping (Intent) -> Void) {
        self.commitDelay = Double(commitDelayMs) / 1000.0
        self.onIntent = onIntent
        // We just got triggered by ctrl×2 — second ctrl-down is the trigger.
        // Arm the commit timer in case the user releases ctrl without tapping.
        armCommitTimer()
    }

    func setFilterMode(_ on: Bool) { modeIsFilter = on }

    func install() -> Bool {
        let mask: CGEventMask =
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.flagsChanged.rawValue)
        let opaqueSelf = Unmanaged.passUnretained(self).toOpaque()
        // CGEventTap callback runs on the run loop we attach to (main).
        // CGEvent is not Sendable, but since we're on main already, accessing
        // self's main-isolated state is safe. We use unsafeAssume here because
        // Swift 6's strict concurrency can't reason about the run-loop binding.
        let cb: CGEventTapCallBack = { _, type, cgEvent, refcon in
            guard let refcon else { return Unmanaged.passUnretained(cgEvent) }
            let me = Unmanaged<HSSwitcherKeyHandler>.fromOpaque(refcon).takeUnretainedValue()
            return me.handleUnchecked(type: type, event: cgEvent)
        }
        guard let t = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: cb,
            userInfo: opaqueSelf
        ) else {
            AKError("HSSwitcherKeyHandler: CGEvent.tapCreate failed — grant Accessibility permission (active event taps require Accessibility).")
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

    /// Sendable snapshot of the parts of a CGEvent we care about. Extracting
    /// these on the (already-main) tap thread before crossing into the
    /// MainActor closure is the cleanest way to keep Swift 6 strict
    /// concurrency happy without sacrificing the per-keystroke budget.
    private struct EventSnapshot: Sendable {
        let type: CGEventType
        let keyCode: Int
        let flags: CGEventFlags
        let characters: String
    }

    /// Nonisolated entry point used by the CGEventTap callback. Extracts a
    /// Sendable snapshot of the event, dispatches on MainActor, and decides
    /// whether to consume or pass through.
    nonisolated private func handleUnchecked(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // Re-enable lifecycle events are handled here without crossing actors.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            reenableTap()
            return Unmanaged.passUnretained(event)
        }
        let snap = EventSnapshot(
            type: type,
            keyCode: Int(event.getIntegerValueField(.keyboardEventKeycode)),
            flags: event.flags,
            characters: Self.unicodeCharacter(of: event) ?? ""
        )
        let consume = MainActor.assumeIsolated { [snap] in
            self.decide(snap: snap)
        }
        return consume ? nil : Unmanaged.passUnretained(event)
    }

    /// Lifecycle re-enable; safe to call from any thread (CGEvent.tapEnable
    /// is thread-safe per Apple docs).
    nonisolated private func reenableTap() {
        // `tap` is main-isolated state; we touch it via assumeIsolated to
        // keep the type system happy. tapEnable itself is thread-safe.
        MainActor.assumeIsolated {
            if let t = tap { CGEvent.tapEnable(tap: t, enable: true) }
        }
    }

    /// Main-isolated decision routine. Returns true = consume, false = pass.
    private func decide(snap: EventSnapshot) -> Bool {
        if snap.type == .flagsChanged {
            updateModifierState(flags: snap.flags)
            return false   // never consume flag-changes
        }
        if snap.type == .keyDown {
            return decideKeyDown(snap: snap)
        }
        return false
    }

    private func updateModifierState(flags: CGEventFlags) {
        let nowCtrl = flags.contains(.maskControl)
        if nowCtrl && !ctrlHeld {
            ctrlHeld = true
            commitTimer?.invalidate(); commitTimer = nil
        } else if !nowCtrl && ctrlHeld {
            ctrlHeld = false
            if !modeIsFilter {
                armCommitTimer()
            }
        }
    }

    /// Returns true to consume the keyDown event.
    private func decideKeyDown(snap: EventSnapshot) -> Bool {
        let keyCode = snap.keyCode
        let flags = snap.flags
        let hasShift = flags.contains(.maskShift)

        // Universal: Escape cancels
        if keyCode == kVK_Escape {
            onIntent(.cancel)
            return true
        }
        switch keyCode {
        case kVK_LeftArrow:  onIntent(.prevApp); return true
        case kVK_RightArrow: onIntent(.nextApp); return true
        case kVK_UpArrow:    onIntent(.prevRow); return true
        case kVK_DownArrow:  onIntent(.nextRow); return true
        default: break
        }
        // Tab while ctrl held: cycle apps (shift reverses)
        if keyCode == kVK_Tab && flags.contains(.maskControl) {
            onIntent(hasShift ? .prevApp : .nextApp)
            return true
        }
        // Enter commits
        if keyCode == kVK_Return || keyCode == kVK_ANSI_KeypadEnter {
            onIntent(.commit)
            return true
        }

        if modeIsFilter {
            if keyCode == kVK_Delete {
                onIntent(.filterBackspace)
                return true
            }
            if !snap.characters.isEmpty,
               let scalar = snap.characters.unicodeScalars.first,
               scalar.value >= 0x20 {       // not a control char
                onIntent(.filterAppend(snap.characters))
                return true
            }
            return true   // filter mode: own the keyboard
        }

        // Cycle mode: plain ASCII letter/digit (no cmd/opt) → enter filter mode.
        let blockingMods: CGEventFlags = [.maskCommand, .maskAlternate]
        if flags.intersection(blockingMods).isEmpty,
           snap.characters.count == 1,
           let scalar = snap.characters.unicodeScalars.first,
           scalar.isASCII,
           (CharacterSet.alphanumerics.contains(scalar) || scalar == " ") {
            onIntent(.enterFilter(snap.characters))
            return true
        }
        // Everything else: pass through.
        return false
    }

    /// Static helper so it can be called from the nonisolated tap callback.
    nonisolated static private func unicodeCharacter(of event: CGEvent) -> String? {
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
                if !self.ctrlHeld && !self.modeIsFilter {
                    self.onIntent(.commit)
                }
            }
        }
    }
}
