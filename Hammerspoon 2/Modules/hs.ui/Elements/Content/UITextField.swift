//
//  UITextField.swift
//  Hammerspoon 2
//
//  Reactive single-line text input element for the hs.ui builder.
//  Backed by an HSString so JS-side reads/writes and Swift-side rendering
//  stay in sync without disturbing sibling elements.
//

import Foundation
import JavaScriptCore
import SwiftUI

/// SwiftUI view that directly observes an HSString so only the field re-renders
/// when its value or focus state changes — not the entire canvas.
private struct ReactiveTextField: View {
    let backing: HSString
    let placeholder: String
    let startFocused: Bool
    let onChange: JSValue?
    let onSubmit: JSValue?
    let onKey: JSValue?
    let font: Font
    let foreground: Color
    let width: CGFloat?
    let height: CGFloat?

    @FocusState private var isFocused: Bool

    var body: some View {
        TextField(placeholder, text: Binding(
            get: { backing.value },
            set: { newVal in
                if backing.value != newVal {
                    backing.set(newVal)
                    onChange?.callSafely(withArguments: [newVal], context: "hs.ui textField onChange")
                }
            }
        ))
        .textFieldStyle(.plain)
        .font(font)
        .foregroundStyle(foreground)
        .focused($isFocused)
        .frame(width: width, height: height)
        .onSubmit {
            onSubmit?.callSafely(withArguments: [backing.value], context: "hs.ui textField onSubmit")
        }
        .onKeyPress(phases: .down) { keyPress in
            guard let onKey = onKey else { return .ignored }
            let key = ReactiveTextField.keyName(for: keyPress)
            let mods = ReactiveTextField.mods(for: keyPress)
            let result = onKey.callSafely(withArguments: [key, mods], context: "hs.ui textField onKey")
            return (result?.toBool() == true) ? .handled : .ignored
        }
        .onAppear {
            if startFocused {
                // Defer to next runloop so the SwiftUI hosting view has installed
                // its responder chain before we grab first-responder.
                DispatchQueue.main.async { isFocused = true }
            }
        }
    }

    static func keyName(for keyPress: KeyPress) -> String {
        switch keyPress.key {
        case .return:        return "Enter"
        case .escape:        return "Escape"
        case .tab:           return "Tab"
        case .upArrow:       return "ArrowUp"
        case .downArrow:     return "ArrowDown"
        case .leftArrow:     return "ArrowLeft"
        case .rightArrow:    return "ArrowRight"
        case .delete:        return "Backspace"
        case .deleteForward: return "Delete"
        default:             return keyPress.characters
        }
    }

    static func mods(for keyPress: KeyPress) -> [String] {
        var result: [String] = []
        let m = keyPress.modifiers
        if m.contains(.command) { result.append("cmd") }
        if m.contains(.control) { result.append("ctrl") }
        if m.contains(.option)  { result.append("opt") }
        if m.contains(.shift)   { result.append("shift") }
        return result   // already alphabetical
    }
}

class UITextField: FrameModifiable, OpacityModifiable, TextModifiable {
    var content: HSString
    var placeholderText: String = ""
    var startFocused: Bool = true
    var font: Font = .body
    var foregroundColor: HSColor? = nil
    var elementFrame: UIFrame? = nil
    var elementOpacity: Double = 1.0

    var onChangeCallback: JSValue? = nil
    var onSubmitCallback: JSValue? = nil
    var onKeyCallback: JSValue? = nil

    init(content: HSString) {
        self.content = content
    }

    func toSwiftUI(containerSize: CGSize) -> AnyView {
        let fg = foregroundColor?.color ?? Color.primary
        let resolved = elementFrame?.resolve(containerSize: containerSize)

        return AnyView(
            ReactiveTextField(
                backing: content,
                placeholder: placeholderText,
                startFocused: startFocused,
                onChange: onChangeCallback,
                onSubmit: onSubmitCallback,
                onKey: onKeyCallback,
                font: font,
                foreground: fg,
                width: resolved?.width,
                height: resolved?.height
            )
            .opacity(elementOpacity)
        )
    }
}
