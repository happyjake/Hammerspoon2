//
//  UICanvasView.swift
//  Hammerspoon 2
//
//  Created by Claude Code on 12/02/2026.
//

import SwiftUI

/// SwiftUI view that renders an HSUIElement tree.
/// Reactive values (HSColor, HSString, HSImage) are observed directly by each element's
/// SwiftUI view, so only the specific element re-renders when a value changes — the rest
/// of the canvas (including any .onHover modifiers) is left untouched.
struct UICanvasView: View {
    let element: any HSUIElement
    let backgroundColor: Color
    let containerSize: CGSize

    var body: some View {
        ZStack(alignment: .topLeading) {
            backgroundColor.ignoresSafeArea()
            // Element gets its natural height (so VStack children don't space
            // out via implicit fill) and the full canvas width. ZStack's
            // .topLeading alignment then anchors the element to the top-left.
            element.toSwiftUI(containerSize: containerSize)
                .frame(width: containerSize.width, alignment: .topLeading)
        }
    }
}
