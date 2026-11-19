import AppKit
import SwiftUI
import UserNotifications
import CleanBunshoCore

@main
struct CleanBunshoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var settings = AppSettings.shared
    @StateObject private var controller = AppController.shared

    var body: some Scene {
        MenuBarExtra {
            MenuContent()
                .environmentObject(settings)
                .environmentObject(controller)
        } label: {
            MenuBarLabel(count: controller.menuBarCount)
        }
        .menuBarExtraStyle(.menu)

        Window("くりーんぶんしょ", id: WindowID.cleaner) {
            CleanerView()
                .environmentObject(settings)
        }
        .defaultSize(width: 920, height: 640)
        .defaultLaunchBehavior(.suppressed)

        Window("くりーんぶんしょ 設定", id: WindowID.settings) {
            SettingsView()
                .environmentObject(settings)
                .environmentObject(controller)
        }
        .windowResizability(.contentSize)
        .defaultLaunchBehavior(.suppressed)
    }
}

enum WindowID {
    static let cleaner = "cleaner"
    static let settings = "settings"
}

final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    private let serviceProvider = ServiceProvider()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Dock に出さない（Info.plist の LSUIElement と同じ。swift run での確認用）
        NSApp.setActivationPolicy(.accessory)
        NSApp.servicesProvider = serviceProvider
        NSUpdateDynamicServices()
        UNUserNotificationCenter.current().delegate = self
        AppController.shared.start()
    }

    // アプリが前面にあっても通知を出す
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner])
    }
}

/// メニューバーのアイコン（アイコンは保留中のため消しゴムのマークを仮で使う）
struct MenuBarLabel: View {
    let count: String?

    var body: some View {
        if let count {
            Text("\(Image(systemName: "eraser")) \(count)")
        } else {
            Image(systemName: "eraser")
        }
    }
}

struct MenuContent: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var controller: AppController
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("クリップボードをきれいにする") {
            controller.cleanClipboardFromMenu()
        }
        if settings.windowEnabled {
            Button("ウィンドウを開く") {
                openWindow(id: WindowID.cleaner)
                NSApp.activate()
            }
        }
        Toggle("自動監視", isOn: $settings.monitorEnabled)
        Divider()
        Button("設定…") {
            openWindow(id: WindowID.settings)
            NSApp.activate()
        }
        .keyboardShortcut(",")
        Divider()
        Button("終了") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
