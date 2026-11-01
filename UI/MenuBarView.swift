import SwiftUI

struct MenuBarView: View {
    @ObservedObject var coordinator: AppCoordinator

    var body: some View {
        Text("app.name").font(.headline)
        Label(statusKey, systemImage: coordinator.monitoringActive ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
        if !coordinator.permissionGranted {
            Button("permission.openSettings") {
                PermissionsManager.openInputMonitoringSettings()
                coordinator.refreshPermission()
            }
        }
        Divider()
        Menu("menu.testTips") {
            Button("tip.copy") { coordinator.tips.show(.copy, force: true) }
            Button("tip.paste") { coordinator.tips.show(.paste, force: true) }
            Button("tip.cut") { coordinator.tips.show(.cut, force: true) }
            Divider()
            Button("test.capsOn") { coordinator.tips.show(.capsLock, state: true, force: true) }
            Button("test.capsOff") { coordinator.tips.show(.capsLock, state: false, force: true) }
        }
        Button("settings.title") { coordinator.showSettings() }
        Divider()
        Button("app.quit", role: .destructive) { NSApp.terminate(nil) }
    }

    private var statusKey: LocalizedStringKey {
        if !coordinator.permissionGranted { "status.permissionRequired" }
        else if coordinator.monitoringActive { "status.monitoring" }
        else { "status.tapFailed" }
    }
}
