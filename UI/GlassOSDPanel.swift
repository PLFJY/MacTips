import AppKit
import SwiftUI

@MainActor
final class GlassOSDPanel: NSPanel {
    private let animationDuration = 0.3
    private let animationDistance: CGFloat = 16
    private var host: NSHostingView<TipContentView>?
    private var lastDirection = SlideDirection.down
    private var targetOrigin = CGPoint.zero
    private var animationTimer: Timer?
    private var animationActivity: NSObjectProtocol?
    private let monitorsMouse: Bool
    private var globalMouseMonitor: Any?
    private var localMouseMonitor: Any?
    private var hoverTimer: Timer?
    private var isHovered = false
    private var hoverOpacity: CGFloat = 1
    private var presentationOpacity: CGFloat = 1 {
        didSet { alphaValue = presentationOpacity * hoverOpacity }
    }
    private var animatesHover = true

    init(monitorsMouse: Bool = true) {
        self.monitorsMouse = monitorsMouse
        super.init(contentRect: CGRect(x: 0, y: 0, width: 190, height: 54),
                   styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isFloatingPanel = true
        becomesKeyOnlyIfNeeded = false
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        backgroundColor = .clear
        isOpaque = false
        // The panel is rectangular; its window shadow would outline transparent corners.
        hasShadow = false
        ignoresMouseEvents = true
    }

    func present(_ tip: TipPresentation, settings: SettingsStore) {
        stopAnimation()
        let root = TipContentView(tip: tip, showCount: settings.showCount)
        if let host { host.rootView = root }
        else {
            let hosting = NSHostingView(rootView: root)
            hosting.frame = contentView?.bounds ?? .zero
            hosting.autoresizingMask = [.width, .height]
            contentView = hosting
            host = hosting
        }
        host?.layoutSubtreeIfNeeded()
        if let fitting = host?.fittingSize { setContentSize(NSSize(width: max(170, fitting.width), height: 54)) }
        let target = origin(for: settings)
        targetOrigin = target
        let speed = settings.animationSpeed
        let shouldAnimate = speed > 0 && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        animatesHover = shouldAnimate
        if !isVisible {
            presentationOpacity = shouldAnimate ? 0 : 1
            setFrameOrigin(shouldAnimate ? displacedOrigin : target)
            orderFrontRegardless()
        }
        startMouseMonitoring()
        updateHover(at: NSEvent.mouseLocation)
        if shouldAnimate {
            animate(to: target, alpha: 1, duration: animationDuration * speed, appearing: true)
        } else {
            setFrameOrigin(target)
            presentationOpacity = 1
        }
    }

    func dismiss(settings: SettingsStore) {
        stopAnimation()
        let speed = settings.animationSpeed
        guard speed > 0, !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else {
            presentationOpacity = 0
            orderOut(nil)
            return
        }
        animate(to: displacedOrigin, alpha: 0, duration: animationDuration * speed, appearing: false)
    }

    private var displacedOrigin: CGPoint {
        CGPoint(x: targetOrigin.x + lastDirection.offset.dx * animationDistance,
                y: targetOrigin.y + lastDirection.offset.dy * animationDistance)
    }

    override func orderOut(_ sender: Any?) {
        stopAnimation()
        hoverTimer?.invalidate()
        hoverTimer = nil
        if let globalMouseMonitor { NSEvent.removeMonitor(globalMouseMonitor) }
        if let localMouseMonitor { NSEvent.removeMonitor(localMouseMonitor) }
        globalMouseMonitor = nil
        localMouseMonitor = nil
        isHovered = false
        hoverOpacity = 1
        super.orderOut(sender)
    }

    private func startMouseMonitoring() {
        guard monitorsMouse, globalMouseMonitor == nil, localMouseMonitor == nil else { return }
        let events: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged]
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: events) { [weak self] _ in
            MainActor.assumeIsolated { self?.updateHover(at: NSEvent.mouseLocation) }
        }
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: events) { [weak self] event in
            MainActor.assumeIsolated { self?.updateHover(at: NSEvent.mouseLocation) }
            return event
        }
    }

    // Mouse tracking areas cannot receive events on a click-through window.
    // Observe movement without consuming it, and animate a separate opacity
    // factor so hovering cannot cancel or brighten an ongoing dismissal.
    func updateHover(at point: CGPoint) {
        let hovered = isVisible && frame.contains(point)
        guard hovered != isHovered else { return }
        isHovered = hovered
        hoverTimer?.invalidate()
        hoverTimer = nil
        let destination: CGFloat = hovered ? 0.25 : 1
        guard animatesHover else {
            hoverOpacity = destination
            alphaValue = presentationOpacity * hoverOpacity
            return
        }
        let start = hoverOpacity
        let startedAt = ProcessInfo.processInfo.systemUptime
        let timer = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            MainActor.assumeIsolated {
                let progress = min(1, (ProcessInfo.processInfo.systemUptime - startedAt) / 0.15)
                let eased = progress * progress * (3 - 2 * progress)
                self.hoverOpacity = start + (destination - start) * eased
                self.alphaValue = self.presentationOpacity * self.hoverOpacity
                if progress >= 1 {
                    self.hoverTimer?.invalidate()
                    self.hoverTimer = nil
                }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        hoverTimer = timer
    }

    private func stopAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
        if let animationActivity { ProcessInfo.processInfo.endActivity(animationActivity) }
        animationActivity = nil
    }

    // Explicit window updates also run while this accessory app is inactive. The
    // timer exists only during a transition and is cancelled by the next tip.
    private func animate(to destination: CGPoint, alpha: CGFloat, duration: TimeInterval, appearing: Bool) {
        animationActivity = ProcessInfo.processInfo.beginActivity(
            options: .userInitiatedAllowingIdleSystemSleep, reason: "Animating a status hint")
        let start = frame.origin
        let startAlpha = presentationOpacity
        let startedAt = ProcessInfo.processInfo.systemUptime
        let timer = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            MainActor.assumeIsolated {
                let progress = min(1, (ProcessInfo.processInfo.systemUptime - startedAt) / duration)
                let eased = appearing ? 1 - pow(1 - progress, 3) : pow(progress, 3)
                self.setFrameOrigin(CGPoint(x: start.x + (destination.x - start.x) * eased,
                                            y: start.y + (destination.y - start.y) * eased))
                self.updateHover(at: NSEvent.mouseLocation)
                self.presentationOpacity = startAlpha + (alpha - startAlpha) * eased
                if progress >= 1 {
                    self.stopAnimation()
                    if !appearing { self.orderOut(nil) }
                }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        animationTimer = timer
    }

    private func origin(for settings: SettingsStore) -> CGPoint {
        let screen: NSScreen = {
            if settings.followsMouse, let mouse = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) }) { return mouse }
            return NSScreen.main ?? NSScreen.screens.first ?? NSScreen()
        }()
        let visible = screen.visibleFrame
        let point = PlacementEngine.origin(visibleFrame: visible, windowSize: frame.size,
                                           horizontal: settings.horizontal, vertical: settings.vertical,
                                           customPosition: settings.customPosition)
        lastDirection = PlacementEngine.slideDirection(origin: point, visibleFrame: visible, windowSize: frame.size)
        return point
    }
}

struct TipContentView: View {
    let tip: TipPresentation
    let showCount: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 11) {
            Image(systemName: tip.kind.symbol)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(.tint)
                .frame(width: 24)
            Text(tip.title)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .lineLimit(1)
                .fixedSize()
            if showCount && tip.kind != .capsLock && tip.count > 1 {
                Text("×\(tip.count)")
                    .font(.system(size: 12, weight: .semibold, design: .rounded).monospacedDigit())
                    .padding(.horizontal, 7).padding(.vertical, 4)
                    .background(.tint.opacity(0.16), in: Capsule())
                    .contentTransition(.numericText())
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 54)
        .background {
            if NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency {
                RoundedRectangle(cornerRadius: 20).fill(Color(nsColor: .windowBackgroundColor))
            } else {
                RoundedRectangle(cornerRadius: 20).fill(.clear).glassEffect(.regular, in: .rect(cornerRadius: 20))
            }
        }
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(.white.opacity(0.13), lineWidth: 0.6))
        .animation(reduceMotion ? nil : .spring(duration: 0.28, bounce: 0.12), value: tip.count)
        .fixedSize()
    }
}
