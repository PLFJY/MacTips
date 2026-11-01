import AppKit
import SwiftUI

@MainActor
final class GlassOSDPanel: NSPanel {
    private var host: NSHostingView<TipContentView>?
    private var lastDirection = SlideDirection.down
    private var animationGeneration = 0

    init() {
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
        animationGeneration += 1
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
        let speed = settings.animationSpeed
        let shouldAnimate = speed > 0 && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        if !isVisible {
            alphaValue = shouldAnimate ? 0 : 1
            let start = CGPoint(x: target.x + lastDirection.offset.dx * 16, y: target.y + lastDirection.offset.dy * 16)
            setFrameOrigin(shouldAnimate ? start : target)
            orderFrontRegardless()
            if shouldAnimate {
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.3 * speed
                    context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                    animator().setFrame(NSRect(origin: target, size: frame.size), display: true)
                    animator().alphaValue = 1
                }
            }
        } else {
            setFrameOrigin(target)
            if shouldAnimate {
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.3 * speed
                    context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                    animator().alphaValue = 1
                }
            } else { alphaValue = 1 }
        }
    }

    func dismiss(settings: SettingsStore) {
        animationGeneration += 1
        let generation = animationGeneration
        let speed = settings.animationSpeed
        guard speed > 0, !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { orderOut(nil); return }
        let exit = CGPoint(x: frame.origin.x + lastDirection.offset.dx * 16, y: frame.origin.y + lastDirection.offset.dy * 16)
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.22 * speed
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            animator().alphaValue = 0
            animator().setFrame(NSRect(origin: exit, size: frame.size), display: true)
        }, completionHandler: { [weak self] in
            MainActor.assumeIsolated {
                guard let self, self.animationGeneration == generation else { return }
                self.orderOut(nil)
                self.alphaValue = 1
            }
        })
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
            if showCount && tip.kind != .capsLock {
                Text("×\(tip.count)")
                    .font(.system(size: 12, weight: .semibold, design: .rounded).monospacedDigit())
                    .padding(.horizontal, 7).padding(.vertical, 4)
                    .background(.tint.opacity(0.16), in: Capsule())
                    .contentTransition(.numericText())
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
