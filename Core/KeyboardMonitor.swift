import AppKit
import ApplicationServices

@MainActor
final class KeyboardMonitor: @unchecked Sendable {
    var onClipboardShortcut: ((ClipboardEventCorrelator.Intent, Int) -> Void)?
    var onPaste: (() -> Void)?
    var onCapsLock: ((Bool) -> Void)?
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var capsState = false

    var isRunning: Bool { tap != nil }

    func start() -> Bool {
        guard tap == nil, CGPreflightListenEventAccess() else { return false }
        capsState = CGEventSource.flagsState(.combinedSessionState).contains(.maskAlphaShift)
        let mask = (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.keyUp.rawValue) | (1 << CGEventType.flagsChanged.rawValue)
        guard let newTap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
                                             options: .listenOnly, eventsOfInterest: CGEventMask(mask),
                                             callback: keyboardEventCallback,
                                             userInfo: Unmanaged.passUnretained(self).toOpaque()) else { return false }
        tap = newTap
        source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, newTap, 0)
        if let source { CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes) }
        CGEvent.tapEnable(tap: newTap, enable: true)
        return true
    }

    func stop() {
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        source = nil
        tap = nil
    }

    fileprivate func receive(type: UInt32, key: Int64, flags: UInt64, isRepeat: Bool) {
        if type == CGEventType.tapDisabledByTimeout.rawValue || type == CGEventType.tapDisabledByUserInput.rawValue {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return
        }
        let eventType = CGEventType(rawValue: type) ?? .null
        let eventFlags = CGEventFlags(rawValue: flags)
        if eventType == .keyDown {
            switch KeyboardShortcutClassifier.classify(keyCode: key, flags: eventFlags, isRepeat: isRepeat) {
            case .copy: onClipboardShortcut?(.copy, NSPasteboard.general.changeCount)
            case .cut: onClipboardShortcut?(.cut, NSPasteboard.general.changeCount)
            case .paste: Task { @MainActor [weak self] in self?.onPaste?() }
            case nil: break
            }
        } else if eventType == .flagsChanged, key == 57 {
            let next = eventFlags.contains(.maskAlphaShift)
            if next != capsState {
                capsState = next
                Task { @MainActor [weak self] in self?.onCapsLock?(next) }
            }
        }
    }
}

private func keyboardEventCallback(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent,
                                   userInfo: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    guard let userInfo else { return Unmanaged.passUnretained(event) }
    let monitor = Unmanaged<KeyboardMonitor>.fromOpaque(userInfo).takeUnretainedValue()
    let key = event.getIntegerValueField(.keyboardEventKeycode)
    let flags = event.flags.rawValue
    let isRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
    // The tap source is installed on the main run loop. Classify synchronously there so
    // a clipboard poll cannot overtake the key intent; the callback itself performs no UI work.
    MainActor.assumeIsolated {
        monitor.receive(type: type.rawValue, key: key, flags: flags, isRepeat: isRepeat)
    }
    return Unmanaged.passUnretained(event)
}
