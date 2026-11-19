import AppKit
import ApplicationServices
import Carbon.HIToolbox
import ServiceManagement
import UserNotifications

/// 自動貼り付け（⌘V を送る）。アクセシビリティの許可が必要
enum Paster {
    static var isTrusted: Bool { AXIsProcessTrusted() }

    /// 許可を求めるダイアログを出す（未許可のときだけ表示される）
    @discardableResult
    static func requestTrust() -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        return AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    static func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    /// ショートカットの修飾キー（⌃⌥⌘）が離されるのを待ってから ⌘V を送る
    static func pasteWhenModifiersReleased(timeout: TimeInterval = 1.0) {
        let deadline = Date().addingTimeInterval(timeout)
        func attempt() {
            let flags = CGEventSource.flagsState(.combinedSessionState)
            let held = flags.intersection([.maskCommand, .maskControl, .maskAlternate, .maskShift])
            if held.isEmpty || Date() > deadline {
                sendCommandV()
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) { attempt() }
            }
        }
        attempt()
    }

    private static func sendCommandV() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let key = CGKeyCode(kVK_ANSI_V)
        let down = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: true)
        down?.flags = .maskCommand
        let up = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: false)
        up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }
}

/// 通知
enum Notifier {
    static func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { _, _ in }
    }

    static func post(_ body: String) {
        let content = UNMutableNotificationContent()
        content.title = "くりーんぶんしょ"
        content.body = body
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}

/// ログイン時に起動
enum LoginItem {
    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    /// 成功したら nil、失敗したらエラーの説明
    static func set(_ enabled: Bool) -> String? {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            return nil
        } catch {
            return error.localizedDescription
        }
    }
}
