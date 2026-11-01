import AppKit
import Combine

@MainActor
final class AppCoordinator: ObservableObject {
    let settings = SettingsStore.shared
    let keyboard = KeyboardMonitor()
    let clipboard = ClipboardMonitor()
    let tips: TipCoordinator
    @Published private(set) var permissionGranted = PermissionsManager.inputMonitoringGranted
    @Published private(set) var monitoringActive = false
    private var settingsObservation: AnyCancellable?
    private var activationObserver: NSObjectProtocol?
    private var terminationObserver: NSObjectProtocol?

    init() {
        tips = TipCoordinator(settings: settings)
        settingsObservation = settings.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refreshPermission() }
        }
        terminationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification, object: nil, queue: .main
        ) { [weak self] _ in Task { @MainActor in self?.stop() } }
        keyboard.onClipboardShortcut = { [weak self] intent, changeCount in
            guard let self else { return }
            self.correlator.record(intent, changeCount: changeCount,
                                   at: ProcessInfo.processInfo.systemUptime)
        }
        keyboard.onPaste = { [weak self] in self?.tips.show(.paste) }
        keyboard.onCapsLock = { [weak self] state in self?.tips.show(.capsLock, state: state) }
        clipboard.onChange = { [weak self] count, hasTypes, time in
            guard let self else { return }
            let outputs = self.correlator.clipboardChanged(to: count, hasTypes: hasTypes,
                                                           at: time, showAnyCopy: self.settings.showAnyCopy && self.settings.showCopy)
            outputs.forEach { output in
                switch output {
                case .confirmed(let kind): self.tips.show(kind)
                case .inferredCopy: self.tips.show(.copy)
                }
            }
        }
        correlator = ClipboardEventCorrelator(initialChangeCount: NSPasteboard.general.changeCount)
        clipboard.start()
        refreshPermission()
    }

    private var correlator: ClipboardEventCorrelator!

    func refreshPermission() {
        permissionGranted = PermissionsManager.inputMonitoringGranted
        if permissionGranted { monitoringActive = keyboard.isRunning || keyboard.start() }
        else { keyboard.stop(); monitoringActive = false }
    }

    func requestPermission() {
        _ = PermissionsManager.requestInputMonitoring()
        refreshPermission()
    }

    func stop() {
        keyboard.stop()
        monitoringActive = false
        clipboard.stop()
        if let activationObserver { NSWorkspace.shared.notificationCenter.removeObserver(activationObserver) }
        if let terminationObserver { NotificationCenter.default.removeObserver(terminationObserver) }
        activationObserver = nil
        terminationObserver = nil
    }
}
