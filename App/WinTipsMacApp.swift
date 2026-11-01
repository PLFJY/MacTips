import SwiftUI

@main
struct WinTipsMacApp: App {
    @StateObject private var coordinator = AppCoordinator()

    var body: some Scene {
        MenuBarExtra("WinTipsMac", systemImage: "capslock") {
            MenuBarView(coordinator: coordinator)
                .environment(\.locale, coordinator.settings.activeLocale)
        }
        .menuBarExtraStyle(.menu)

        Window("settings.title", id: "settings") {
            SettingsView(coordinator: coordinator)
                .environmentObject(coordinator.settings)
                .environment(\.locale, coordinator.settings.activeLocale)
                .frame(minWidth: 520, minHeight: 490)
        }
        .defaultSize(width: 600, height: 560)
    }
}
