import Foundation

/// US-ANSI virtual key codes (the values `CGEvent` expects in
/// `kCGKeyboardEventKeycode`). These are **hardware** codes and are NOT
/// alphabetical — `a` is 0, `s` is 1, `d` is 2, and so on.
public enum KeyCodeMap {

    /// Letter → virtual keycode (US ANSI layout).
    public static let letters: [Character: Int32] = [
        "a": 0,  "s": 1,  "d": 2,  "f": 3,  "h": 4,  "g": 5,
        "z": 6,  "x": 7,  "c": 8,  "v": 9,  "b": 11, "q": 12,
        "w": 13, "e": 14, "r": 15, "y": 16, "t": 17, "o": 31,
        "u": 32, "i": 34, "p": 35, "l": 37, "j": 38, "k": 40,
        "n": 45, "m": 46,
    ]

    /// Digit → virtual keycode (top row; deliberately non-contiguous).
    public static let digits: [Character: Int32] = [
        "1": 18, "2": 19, "3": 20, "4": 21, "5": 23,
        "6": 22, "7": 26, "8": 28, "9": 25, "0": 29,
    ]

    /// Punctuation → virtual keycode (US ANSI layout, unshifted).
    public static let punctuation: [Character: Int32] = [
        "=": 24, "-": 27, "]": 30, "[": 33, "'": 39, ";": 41,
        "\\": 42, ",": 43, "/": 44, ".": 47, "`": 50, " ": 49,
    ]

    /// Special key → virtual keycode.
    public static func code(for special: SpecialKey) -> Int32 {
        switch special {
        case .enter: return 36
        case .tab: return 48
        case .space: return 49
        case .escape: return 53
        case .delete: return 117      // forward delete
        case .backspace: return 51    // delete-left
        case .home: return 115
        case .end: return 119
        case .pageUp: return 116
        case .pageDown: return 121
        case .leftArrow: return 123
        case .rightArrow: return 124
        case .upArrow: return 126
        case .downArrow: return 125
        case .f1: return 122
        case .f2: return 120
        case .f3: return 99
        case .f4: return 118
        case .f5: return 96
        case .f6: return 97
        case .f7: return 98
        case .f8: return 100
        case .f9: return 101
        case .f10: return 109
        case .f11: return 103
        case .f12: return 111
        }
    }

    /// Resolve a `KeyCode` to a virtual keycode and whether Shift is implied
    /// (e.g. an uppercase letter). Returns `nil` if the character is not on the
    /// ANSI layout (callers should fall back to Unicode typing).
    public static func resolve(_ keyCode: KeyCode) -> (code: Int32, needsShift: Bool)? {
        switch keyCode {
        case .special(let s):
            return (code(for: s), false)
        case .character(let ch):
            let needsShift = ch.isUppercase
            let lower = Character(ch.lowercased())
            if let c = letters[lower] { return (c, needsShift) }
            if let c = digits[lower] { return (c, needsShift) }
            if let c = punctuation[lower] { return (c, needsShift) }
            return nil
        }
    }
}
