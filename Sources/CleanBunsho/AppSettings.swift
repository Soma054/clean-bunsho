import Foundation
import CleanBunshoCore

/// 設定（各自の Mac の UserDefaults に保存。共有の仕組みは持たない）
@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()
    private let defaults = UserDefaults.standard

    private enum Key {
        static let options = "cleanOptions"
        static let shortcutEnabled = "mode.shortcut"
        static let monitorEnabled = "mode.monitor"
        static let windowEnabled = "mode.window"
        static let serviceEnabled = "mode.service"
        static let shortcut = "shortcut"
        static let shortcutUnset = "shortcut.unset"
        static let autoPaste = "shortcut.autoPaste"
        static let notify = "general.notify"
        static let flashCount = "general.flashCount"
    }

    // MARK: 処理ルール
    @Published var options: CleanOptions { didSet { saveCodable(options, Key.options) } }

    // MARK: 使い方（4つのモード）
    @Published var shortcutEnabled: Bool { didSet { defaults.set(shortcutEnabled, forKey: Key.shortcutEnabled) } }
    @Published var monitorEnabled: Bool { didSet { defaults.set(monitorEnabled, forKey: Key.monitorEnabled) } }
    @Published var windowEnabled: Bool { didSet { defaults.set(windowEnabled, forKey: Key.windowEnabled) } }
    @Published var serviceEnabled: Bool { didSet { defaults.set(serviceEnabled, forKey: Key.serviceEnabled) } }
    /// nil は「未設定」
    @Published var shortcut: KeyCombo? {
        didSet {
            if let shortcut {
                saveCodable(shortcut, Key.shortcut)
                defaults.set(false, forKey: Key.shortcutUnset)
            } else {
                defaults.removeObject(forKey: Key.shortcut)
                defaults.set(true, forKey: Key.shortcutUnset)
            }
        }
    }
    /// ショートカットの後に自動で貼り付けるか
    @Published var autoPaste: Bool { didSet { defaults.set(autoPaste, forKey: Key.autoPaste) } }

    // MARK: 一般
    @Published var notify: Bool { didSet { defaults.set(notify, forKey: Key.notify) } }
    @Published var flashCount: Bool { didSet { defaults.set(flashCount, forKey: Key.flashCount) } }

    private init() {
        let d = UserDefaults.standard
        func bool(_ key: String, _ fallback: Bool) -> Bool {
            d.object(forKey: key) == nil ? fallback : d.bool(forKey: key)
        }
        options = Self.loadCodable(CleanOptions.self, Key.options, d) ?? .default
        shortcutEnabled = bool(Key.shortcutEnabled, true)
        monitorEnabled = bool(Key.monitorEnabled, false)
        windowEnabled = bool(Key.windowEnabled, true)
        serviceEnabled = bool(Key.serviceEnabled, true)
        if d.bool(forKey: Key.shortcutUnset) {
            shortcut = nil
        } else {
            shortcut = Self.loadCodable(KeyCombo.self, Key.shortcut, d) ?? .defaultCombo
        }
        autoPaste = bool(Key.autoPaste, true)
        notify = bool(Key.notify, true)
        flashCount = bool(Key.flashCount, true)
    }

    func resetRules() {
        options = .default
    }

    private func saveCodable<T: Encodable>(_ value: T, _ key: String) {
        if let data = try? JSONEncoder().encode(value) { defaults.set(data, forKey: key) }
    }

    private static func loadCodable<T: Decodable>(_ type: T.Type, _ key: String, _ d: UserDefaults) -> T? {
        guard let data = d.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}
