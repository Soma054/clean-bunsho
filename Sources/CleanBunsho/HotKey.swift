import Carbon.HIToolbox

/// システム全体のショートカット（Carbon の RegisterEventHotKey を使う。アクセシビリティ許可は不要）
final class HotKey {
    /// 押されたときに呼ばれる（メインスレッド）
    static var onPress: (() -> Void)?
    private static var handlerInstalled = false

    private var ref: EventHotKeyRef?

    static func installHandler() {
        guard !handlerInstalled else { return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            HotKey.onPress?()
            return noErr
        }, 1, &spec, nil, nil)
        handlerInstalled = true
    }

    /// 登録する。他のアプリが使っているなどで失敗したら false
    @discardableResult
    func register(_ combo: KeyCombo) -> Bool {
        unregister()
        let hotKeyID = EventHotKeyID(signature: OSType(0x4342_4E53), id: 1) // 'CBNS'
        var newRef: EventHotKeyRef?
        let status = RegisterEventHotKey(
            combo.keyCode, combo.carbonModifiers, hotKeyID,
            GetApplicationEventTarget(), 0, &newRef
        )
        guard status == noErr, let newRef else { return false }
        ref = newRef
        return true
    }

    func unregister() {
        if let ref { UnregisterEventHotKey(ref) }
        ref = nil
    }

    var isRegistered: Bool { ref != nil }
}
