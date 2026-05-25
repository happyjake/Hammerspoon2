//
//  UICanvasView.swift
//  Hammerspoon 2
//
//  Created by Claude Code on 12/02/2026.
//

import AppKit
import SwiftUI

/// SwiftUI view that renders an HSUIElement tree.
/// Reactive values (HSColor, HSString, HSImage) are observed directly by each element's
/// SwiftUI view, so only the specific element re-renders when a value changes — the rest
/// of the canvas (including any .onHover modifiers) is left untouched.
struct UICanvasView: View {
    let element: any HSUIElement
    let backgroundColor: Color
    let containerSize: CGSize

    /// Pick a color scheme based on the background's perceived luminance.
    /// Dark backgrounds get `.dark` so SwiftUI secondary colors (notably
    /// TextField placeholder text) render with proper contrast — otherwise
    /// a borderless dark popup would inherit the system "light" appearance
    /// and the placeholder would be nearly invisible.
    private var resolvedColorScheme: ColorScheme {
        let ns = NSColor(backgroundColor).usingColorSpace(.sRGB)
        guard let c = ns else { return .light }
        let lum = 0.299 * c.redComponent + 0.587 * c.greenComponent + 0.114 * c.blueComponent
        return lum < 0.5 ? .dark : .light
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            backgroundColor.ignoresSafeArea()
            // Element gets its natural height (so VStack children don't space
            // out via implicit fill) and the full canvas width. ZStack's
            // .topLeading alignment then anchors the element to the top-left.
            element.toSwiftUI(containerSize: containerSize)
                .frame(width: containerSize.width, alignment: .topLeading)
        }
        .environment(\.colorScheme, resolvedColorScheme)
    }
}
