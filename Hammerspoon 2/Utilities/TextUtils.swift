//
//  TextUtils.swift
//  Hammerspoon 2
//
//  Cross-module helpers for CJK pinyin conversion and ASCII input-source
//  switching. Used by `hs.text` (JS-facing) and internally by `hs.switcher`
//  (so its filter-mode also supports pinyin search and Latin keystrokes).
//

import Foundation
import Carbon

/// Convert Mandarin characters in a string to lowercase pinyin, stripped of
/// tone diacritics and inter-syllable whitespace. Non-CJK characters pass
/// through (lowercased).
///
/// Examples:
///   "微信"        → "weixin"
///   "支付宝"       → "zhifubao"
///   "Hello 世界"  → "hello shijie"
func mandarinToPinyin(_ s: String) -> String {
    guard !s.isEmpty else { return "" }
    let mutable = NSMutableString(string: s)
    CFStringTransform(mutable, nil, kCFStringTransformMandarinLatin, false)
    CFStringTransform(mutable, nil, kCFStringTransformStripDiacritics, false)
    return (mutable as String)
        .lowercased()
        .components(separatedBy: .whitespaces)
        .joined()
}

/// Switch the current keyboard input source to an ASCII-capable layout
/// (the most-recently-used one). No-op if already on ASCII. Returns true
/// on success.
func switchToASCIIInputSource() -> Bool {
    guard let unmanaged = TISCopyCurrentASCIICapableKeyboardInputSource() else {
        return false
    }
    let src = unmanaged.takeRetainedValue()
    return TISSelectInputSource(src) == noErr
}

/// Process-wide cache of `mandarinToPinyin` results. Used by anything that
/// matches against pinyin in a hot path (the switcher filter, mostly).
/// Bounded by `cap` to avoid runaway growth.
final class PinyinCache {
    static let shared = PinyinCache()
    private var store: [String: String] = [:]
    private let cap = 4096
    private let lock = NSLock()

    func get(_ s: String) -> String {
        lock.lock(); defer { lock.unlock() }
        if let cached = store[s] { return cached }
        let v = mandarinToPinyin(s)
        if store.count >= cap { store.removeAll() }   // crude eviction
        store[s] = v
        return v
    }
}
