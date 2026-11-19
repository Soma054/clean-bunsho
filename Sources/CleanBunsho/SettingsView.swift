import AppKit
import SwiftUI
import Carbon.HIToolbox
import CleanBunshoCore

/// 設定ウィンドウ（一般・使い方・処理ルール の3タブ）
struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralTab()
                .tabItem { Label("一般", systemImage: "gearshape") }
            ModesTab()
                .tabItem { Label("使い方", systemImage: "keyboard") }
            RulesTab()
                .tabItem { Label("処理ルール", systemImage: "list.bullet") }
        }
        .frame(width: 560)
        .frame(minHeight: 460)
    }
}

// MARK: - 一般

private struct GeneralTab: View {
    @EnvironmentObject private var settings: AppSettings
    @State private var launchAtLogin = LoginItem.isEnabled
    @State private var loginError: String?

    var body: some View {
        Form {
            Toggle("ログイン時に起動", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, newValue in
                    guard newValue != LoginItem.isEnabled else { return }
                    loginError = LoginItem.set(newValue)
                    launchAtLogin = LoginItem.isEnabled
                }
            if let loginError {
                Text(loginError).font(.caption).foregroundStyle(.red)
            }
            Toggle("通知を出す（「3個を削除しました」など）", isOn: $settings.notify)
                .onChange(of: settings.notify) { _, on in
                    if on { Notifier.requestAuthorization() }
                }
            Toggle("メニューバーに削除数を一瞬表示", isOn: $settings.flashCount)
        }
        .formStyle(.grouped)
        .onAppear { launchAtLogin = LoginItem.isEnabled }
    }
}

// MARK: - 使い方

private struct ModesTab: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var controller: AppController
    @State private var trusted = Paster.isTrusted
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        Form {
            Section {
                Toggle("ショートカット", isOn: $settings.shortcutEnabled)
                if settings.shortcutEnabled {
                    LabeledContent("キー") { ShortcutRecorder() }
                    if let notice = controller.shortcutNotice {
                        Label(notice, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                    Picker("押したあと", selection: $settings.autoPaste) {
                        Text("きれいにして自動で貼り付ける").tag(true)
                        Text("きれいにするだけ").tag(false)
                    }
                    if settings.autoPaste {
                        LabeledContent("アクセシビリティ") {
                            if trusted {
                                Label("許可済み", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                            } else {
                                Button("許可する…") {
                                    Paster.requestTrust()
                                    Paster.openAccessibilitySettings()
                                }
                            }
                        }
                    }
                }
            } footer: {
                Text("コピーしたあとにキーを押すと、クリップボードをきれいにして貼り付けます。後から他のアプリが同じキーを使った場合は検出できないので、効かないときはキーを変えてください。")
            }

            Section {
                Toggle("クリップボード自動監視", isOn: $settings.monitorEnabled)
            } footer: {
                Text("コピーされた文字を自動できれいにして上書きします。パスワード管理アプリからのコピーには触りません。")
            }

            Section {
                Toggle("ウィンドウ", isOn: $settings.windowEnabled)
            } footer: {
                Text("メニューバーの「ウィンドウを開く」から、貼り付けて確認してからコピーできます。")
            }

            Section {
                Toggle("右クリックメニュー", isOn: $settings.serviceEnabled)
            } footer: {
                Text("文字を選んで右クリック →「サービス」→「きれいにする」で、選んだ箇所をその場で置き換えます。メニューに出ないときは「システム設定 → キーボード → キーボードショートカット → サービス」で「きれいにする」をオンにしてください。")
            }
        }
        .formStyle(.grouped)
        .onReceive(timer) { _ in trusted = Paster.isTrusted }
    }
}

/// ショートカットの割り当て（ボタンを押してからキーを押す）
private struct ShortcutRecorder: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var controller: AppController
    @State private var recording = false
    @State private var eventMonitor: Any?

    var body: some View {
        HStack(spacing: 6) {
            Button {
                recording ? stop() : start()
            } label: {
                Text(recording ? "キーを押してください…" : (settings.shortcut?.displayString ?? "未設定"))
                    .frame(minWidth: 130)
            }
            if !recording, settings.shortcut != nil {
                Button("消去") { settings.shortcut = nil }
            }
            if !recording, settings.shortcut != KeyCombo.defaultCombo {
                Button("既定（⌃⌥⌘V）") {
                    controller.shortcutNotice = nil
                    settings.shortcut = .defaultCombo
                }
            }
        }
        .onDisappear { stop() }
    }

    private func start() {
        recording = true
        controller.suspendHotKey()
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == UInt16(kVK_Escape) {
                stop()
                return nil
            }
            if let combo = KeyCombo(event: event) {
                controller.shortcutNotice = nil
                settings.shortcut = combo
                stop()
            } else {
                NSSound.beep() // ⌘・⌃・⌥ のどれかと組み合わせる
            }
            return nil
        }
    }

    private func stop() {
        if let eventMonitor { NSEvent.removeMonitor(eventMonitor) }
        eventMonitor = nil
        if recording {
            recording = false
            controller.resumeHotKey()
        }
    }
}

// MARK: - 処理ルール

private struct RulesTab: View {
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        Form {
            Section {
                ForEach(Rule.allCases) { rule in
                    Toggle(isOn: binding(for: rule)) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(rule.title)
                            Text("\(rule.target) → \(rule.action)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } footer: {
                Text("絵文字の間にあるゼロ幅接合子（👨‍👩‍👧 など）と、旗の絵文字のタグ文字は常に残します。")
            }
            Section {
                Button("既定に戻す") { settings.resetRules() }
                    .disabled(settings.options == .default)
            }
        }
        .formStyle(.grouped)
    }

    private func binding(for rule: Rule) -> Binding<Bool> {
        Binding(
            get: { settings.options[rule] },
            set: { settings.options[rule] = $0 }
        )
    }
}
