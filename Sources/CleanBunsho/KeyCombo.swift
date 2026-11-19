import AppKit
import Carbon.HIToolbox

/// ショートカットのキーの組み合わせ（Carbon のキーコードと修飾キー）
struct KeyCombo: Codable, Equatable {
    var keyCode: UInt32
    var carbonModifiers: UInt32
    /// 表示用のキー名（"V" など）
    var keyLabel: String

    /// 既定は ⌃⌥⌘V（Finder の ⌥⌘V との重なりを避ける）
    static let defaultCombo = KeyCombo(
        keyCode: UInt32(kVK_ANSI_V),
        carbonModifiers: UInt32(controlKey | optionKey | cmdKey),
        keyLabel: "V"
    )

    var displayString: String {
        var s = ""
        if carbonModifiers & UInt32(controlKey) != 0 { s += "⌃" }
        if carbonModifiers & UInt32(optionKey) != 0 { s += "⌥" }
        if carbonModifiers & UInt32(shiftKey) != 0 { s += "⇧" }
        if carbonModifiers & UInt32(cmdKey) != 0 { s += "⌘" }
        return s + keyLabel
    }

    /// キー入力から作る。⌘・⌃・⌥ のどれも押されていなければ nil（誤爆防止）
    init?(event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        var mods: UInt32 = 0
        if flags.contains(.command) { mods |= UInt32(cmdKey) }
        if flags.contains(.option) { mods |= UInt32(optionKey) }
        if flags.contains(.control) { mods |= UInt32(controlKey) }
        if flags.contains(.shift) { mods |= UInt32(shiftKey) }
        guard mods & UInt32(cmdKey | optionKey | controlKey) != 0 else { return nil }
        keyCode = UInt32(event.keyCode)
        carbonModifiers = mods
        keyLabel = KeyCombo.label(for: event)
    }

    init(keyCode: UInt32, carbonModifiers: UInt32, keyLabel: String) {
        self.keyCode = keyCode
        self.carbonModifiers = carbonModifiers
        self.keyLabel = keyLabel
    }

    private static func label(for event: NSEvent) -> String {
        let special: [Int: String] = [
            kVK_Space: "Space", kVK_Return: "↩", kVK_Tab: "⇥", kVK_Delete: "⌫",
            kVK_ForwardDelete: "⌦", kVK_LeftArrow: "←", kVK_RightArrow: "→",
            kVK_UpArrow: "↑", kVK_DownArrow: "↓", kVK_Home: "↖", kVK_End: "↘",
            kVK_PageUp: "⇞", kVK_PageDown: "⇟",
            kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5", kVK_F6: "F6",
            kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12",
        ]
        if let s = special[Int(event.keyCode)] { return s }
        let chars = event.charactersIgnoringModifiers ?? ""
        return chars.isEmpty ? "#\(event.keyCode)" : chars.uppercased()
    }
}
