import AppKit
import Combine
import CleanBunshoCore

/// 4つのモードと通知・メニューバー表示をまとめて動かす
@MainActor
final class AppController: ObservableObject {
    static let shared = AppController()

    enum ShortcutStatus: Equatable {
        case off          // モードがオフ
        case unset        // 未設定
        case registered   // 有効
    }

    @Published private(set) var shortcutStatus: ShortcutStatus = .off
    /// 登録できなかったときの知らせ（設定画面に出す）
    @Published var shortcutNotice: String?
    /// メニューバーに一瞬出す件数
    @Published private(set) var menuBarCount: String?

    let settings = AppSettings.shared
    private let hotKey = HotKey()
    private let monitor = ClipboardMonitor()
    private var cancellables = Set<AnyCancellable>()
    private var hotKeySuspended = false
    private var flashToken = 0

    private init() {}

    func start() {
        HotKey.onPress = {
            MainActor.assumeIsolated { AppController.shared.handleHotKey() }
        }
        HotKey.installHandler()
        monitor.onChange = { [weak self] in self?.handleClipboardChange() }

        applyShortcut()
        applyMonitor()

        // @Published は値が変わる直前に知らせるため、次の周回で反映する
        Publishers.Merge(
            settings.$shortcutEnabled.map { _ in () },
            settings.$shortcut.map { _ in () }
        )
        .dropFirst(2)
        .receive(on: DispatchQueue.main)
        .sink { [weak self] in self?.applyShortcut() }
        .store(in: &cancellables)

        settings.$monitorEnabled
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.applyMonitor() }
            .store(in: &cancellables)

        if settings.notify { Notifier.requestAuthorization() }
    }

    // MARK: ショートカット

    func applyShortcut() {
        guard !hotKeySuspended else { return }
        guard settings.shortcutEnabled else {
            hotKey.unregister()
            shortcutStatus = .off
            return
        }
        guard let combo = settings.shortcut else {
            hotKey.unregister()
            shortcutStatus = .unset
            return
        }
        if hotKey.register(combo) {
            shortcutStatus = .registered
            shortcutNotice = nil
        } else {
            // 他のアプリが先に使っている → 「未設定」にして知らせる
            hotKey.unregister()
            shortcutStatus = .unset
            shortcutNotice = "\(combo.displayString) は他のアプリが使っているため登録できませんでした。別のキーを設定してください。"
            settings.shortcut = nil
        }
    }

    /// キーの割り当て中は一時的に外す（今のキーも入力できるように）
    func suspendHotKey() {
        hotKeySuspended = true
        hotKey.unregister()
    }

    func resumeHotKey() {
        hotKeySuspended = false
        applyShortcut()
    }

    private func handleHotKey() {
        let result = PasteboardCleaner.clean(options: settings.options)
        monitor.markOwnWrite()
        report(result)

        guard settings.autoPaste else { return }
        if Paster.isTrusted {
            Paster.pasteWhenModifiersReleased()
        } else {
            Paster.requestTrust()
            if settings.notify {
                Notifier.post("自動で貼り付けるには「アクセシビリティ」の許可が必要です。きれいにした文章はクリップボードに入っています。")
            }
        }
    }

    // MARK: クリップボード自動監視

    private func applyMonitor() {
        if settings.monitorEnabled { monitor.start() } else { monitor.stop() }
    }

    private func handleClipboardChange() {
        // パスワード管理アプリなどの秘密情報は触らない
        guard !PasteboardCleaner.isSensitive() else { return }
        let result = PasteboardCleaner.clean(options: settings.options)
        monitor.markOwnWrite()
        report(result)
    }

    // MARK: メニュー

    /// メニューバーから：きれいにするだけで貼り付けはしない
    func cleanClipboardFromMenu() {
        let result = PasteboardCleaner.clean(options: settings.options)
        monitor.markOwnWrite()
        report(result)
        if result == nil, settings.notify {
            Notifier.post("クリップボードに文字が入っていません。")
        }
    }

    // MARK: 右クリックメニュー（サービス）

    /// 成功なら nil、失敗ならエラーの説明
    func handleService(_ pb: NSPasteboard) -> String? {
        guard settings.serviceEnabled else {
            return "右クリックメニューは設定でオフになっています。"
        }
        guard let text = pb.string(forType: .string) else {
            return "文字を読み取れませんでした。"
        }
        let result = Cleaner.clean(text, options: settings.options)
        pb.clearContents()
        pb.setString(result.text, forType: .string)
        report(result)
        return nil
    }

    // MARK: 知らせる

    private func report(_ result: CleanResult?) {
        guard let result, let message = result.summaryMessage else { return }
        if settings.notify { Notifier.post(message) }
        if settings.flashCount { flash(String(result.totalCount)) }
    }

    private func flash(_ text: String) {
        flashToken += 1
        let token = flashToken
        menuBarCount = text
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            guard let self, self.flashToken == token else { return }
            self.menuBarCount = nil
        }
    }
}

/// macOS の「サービス」から呼ばれる（Info.plist の NSServices で登録）
final class ServiceProvider: NSObject {
    @objc(cleanText:userData:error:)
    func cleanText(_ pboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString>) {
        let message: String? = MainActor.assumeIsolated {
            AppController.shared.handleService(pboard)
        }
        if let message { error.pointee = message as NSString }
    }
}
