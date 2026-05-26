//
//  UIAttributedText.swift
//  Hammerspoon 2
//
//  Created by Claude Code on 26/05/2026.
//
//  Inline multi-color text built from a JSON-encoded segments array carried
//  by an HSString. Each segment renders as one concatenated SwiftUI Text
//  chunk with its own color, so visually it's a single inline string with
//  mixed colors. Used by the launcher for per-character fuzzy-match
//  highlighting.

import Foundation
import SwiftUI

/// Parsed segment from the JSON backing string.
private struct AttrSegment {
    let text: String
    let accent: Bool
}

/// SwiftUI view that observes an HSString carrying a JSON-encoded segments
/// array and renders it as a single line of concatenated, per-segment colored
/// Text. SwiftUI re-renders only this view when the backing's value changes.
private struct ReactiveAttributedText: View {
    var content: HSString
    let font: Font
    let defaultColor: Color
    let accentColor: Color
    let opacity: Double
    let width: CGFloat?
    let height: CGFloat?

    var body: some View {
        buildText()
            .font(font)
            .opacity(opacity)
            .lineLimit(1)
            .truncationMode(.tail)
            .multilineTextAlignment(.leading)
            .frame(width: width, height: height, alignment: .leading)
    }

    private func buildText() -> Text {
        let segs = Self.parse(content.value)
        if segs.isEmpty { return Text(content.value).foregroundColor(defaultColor) }
        return segs.reduce(Text("")) { acc, s in
            acc + Text(s.text).foregroundColor(s.accent ? accentColor : defaultColor)
        }
    }

    private static func parse(_ json: String) -> [AttrSegment] {
        guard let data = json.data(using: .utf8),
              let arr = (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]]
        else { return [] }
        return arr.compactMap { dict in
            guard let text = dict["text"] as? String else { return nil }
            return AttrSegment(text: text, accent: (dict["accent"] as? Bool) ?? false)
        }
    }
}

class UIAttributedText: FrameModifiable, OpacityModifiable, TextModifiable, AccentColorModifiable {
    var content: HSString
    var font: Font = .body
    var foregroundColor: HSColor? = nil
    var accentColor: HSColor? = nil
    var elementFrame: UIFrame? = nil
    var elementOpacity: Double = 1.0

    init(content: HSString) {
        self.content = content
    }

    func toSwiftUI(containerSize: CGSize) -> AnyView {
        let fg = foregroundColor?.color ?? Color.primary
        let accent = accentColor?.color ?? Color.accentColor
        let resolved = elementFrame?.resolve(containerSize: containerSize)

        return AnyView(
            ReactiveAttributedText(
                content: content,
                font: font,
                defaultColor: fg,
                accentColor: accent,
                opacity: elementOpacity,
                width: resolved?.width,
                height: resolved?.height
            )
        )
    }
}
