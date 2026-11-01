import AppKit
import ApplicationServices

enum PermissionsManager {
    static var inputMonitoringGranted: Bool { CGPreflightListenEventAccess() }
    @discardableResult static func requestInputMonitoring() -> Bool { CGRequestListenEventAccess() }
    static func openInputMonitoringSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
            NSWorkspace.shared.open(url)
        }
    }
}
