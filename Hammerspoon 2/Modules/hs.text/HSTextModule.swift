//
//  HSTextModule.swift
//  Hammerspoon 2
//
//  Text-processing utilities: pinyin conversion for CJK fuzzy search and
//  ASCII input-source switching for search fields that need Latin keystrokes.
//

import Foundation
import JavaScriptCore
import Carbon
import AppKit

@objc protocol HSTextModuleAPI: JSExport {
    /// Convert Mandarin characters in a string to lowercase pinyin, stripped
    /// of tone diacritics and inter-syllable spaces. Non-CJK characters are
    /// passed through (lowercased). Used by the launcher's fuzzy matcher
    /// and the switcher's filter to match e.g. "weixin" against "微信".
    ///
    /// - Parameter s: input string
    /// - Returns: lowercase pinyin (no spaces, no diacritics)
    /// - Example:
    /// ```js
    /// hs.text.toPinyin('微信')         // → 'weixin'
    /// hs.text.toPinyin('支付宝')        // → 'zhifubao'
    /// hs.text.toPinyin('Hello 世界')    // → 'hello shijie'
    /// ```
    @objc func toPinyin(_ s: String) -> String

    /// Switch the system's current keyboard input source to an ASCII-capable
    /// layout (e.g. "ABC" or "U.S."). The previously-selected ASCII source is
    /// reused. No-op if already on an ASCII source.
    ///
    /// Useful when opening a search field — the user can type Latin letters
    /// even if they were last using a Chinese / Japanese / Korean IME.
    ///
    /// - Returns: true if the switch succeeded (or the current source is
    ///   already ASCII), false if no ASCII source could be located.
    /// - Example:
    /// ```js
    /// hs.text.useASCIIInput()
    /// ```
    @objc func useASCIIInput() -> Bool
}

@_documentation(visibility: private)
@MainActor
@objc class HSTextModule: NSObject, HSModuleAPI, HSTextModuleAPI {
    var name = "hs.text"
    let engineID: UUID

    required init(engineID: UUID) {
        self.engineID = engineID
        super.init()
        AKTrace("Init of \(name): \(engineID)")
    }

    func shutdown() {}

    isolated deinit {
        AKTrace("Deinit of \(name): \(engineID)")
    }

    @objc func toPinyin(_ s: String) -> String { mandarinToPinyin(s) }

    @objc func useASCIIInput() -> Bool { switchToASCIIInputSource() }
}
