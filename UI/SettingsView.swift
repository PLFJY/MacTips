import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @ObservedObject var coordinator: AppCoordinator
    @EnvironmentObject private var settings: SettingsStore
    @State private var launchError: String?
    @State private var editorPoint = CGPoint(x: 0.5, y: 0.5)

    var body: some View {
        TabView {
            clipboardPane.tabItem { Label("settings.clipboard", systemImage: "doc.on.clipboard") }
            appearancePane.tabItem { Label("settings.appearance", systemImage: "rectangle.on.rectangle") }
            systemPane.tabItem { Label("settings.system", systemImage: "gear") }
        }
        .padding(20)
        .alert("settings.launchError", isPresented: Binding(get: { launchError != nil }, set: { if !$0 { launchError = nil } })) {
            Button("common.ok") { launchError = nil }
        } message: { Text(launchError ?? "") }
        .onAppear {
            if let custom = settings.customPosition { editorPoint = CGPoint(x: custom.x, y: 1 - custom.y) }
            else { editorPoint = CGPoint(x: 0.5, y: 0.5) }
        }
    }

    private var clipboardPane: some View {
        Form {
            Section("settings.clipboard") {
                Toggle("settings.copy", isOn: $settings.showCopy)
                Toggle("settings.paste", isOn: $settings.showPaste)
                Toggle("settings.cut", isOn: $settings.showCut)
                Toggle("settings.count", isOn: $settings.showCount)
            }
            Section("settings.keyboard") {
                Toggle("settings.capsLock", isOn: $settings.showCapsLock)
                Text("settings.inputDisclosure").font(.footnote).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private var appearancePane: some View {
        Form {
            Section("settings.duration") {
                Slider(value: $settings.displaySeconds, in: 1...5, step: 0.5) {
                    Text("settings.duration")
                } minimumValueLabel: { Text("1s") } maximumValueLabel: { Text("5s") }
                Text(settings.displaySeconds, format: .number.precision(.fractionLength(1)))
                    .monospacedDigit().foregroundStyle(.secondary)
            }
            Section("settings.animation") {
                Slider(value: $settings.animationSpeed, in: 0...3, step: 0.1)
                Text(settings.animationSpeed == 0 ? String(localized: "settings.animationOff") : String(format: "%.1f×", settings.animationSpeed))
                    .foregroundStyle(.secondary)
            }
            Section("settings.position") {
                Picker("settings.horizontal", selection: $settings.horizontal) {
                    Text("position.left").tag("left")
                    Text("position.center").tag("center")
                    Text("position.right").tag("right")
                }
                Picker("settings.vertical", selection: $settings.vertical) {
                    Text("position.top").tag("top")
                    Text("position.bottom").tag("bottom")
                }
                Toggle("settings.followMouse", isOn: $settings.followsMouse)
                Text("settings.customPosition").font(.subheadline)
                GeometryReader { proxy in
                    ZStack {
                        RoundedRectangle(cornerRadius: 12).fill(.quaternary)
                        RoundedRectangle(cornerRadius: 12).strokeBorder(.secondary.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [5]))
                        Path { path in
                            for fraction in [0.15, 0.5, 0.85] {
                                let x = proxy.size.width * fraction
                                let y = proxy.size.height * fraction
                                path.move(to: CGPoint(x: x, y: 0)); path.addLine(to: CGPoint(x: x, y: proxy.size.height))
                                path.move(to: CGPoint(x: 0, y: y)); path.addLine(to: CGPoint(x: proxy.size.width, y: y))
                            }
                        }
                        .stroke(.secondary.opacity(0.35), style: StrokeStyle(lineWidth: 0.7, dash: [3, 4]))
                        Image(systemName: "capslock.fill")
                            .padding(12).background(.regularMaterial, in: Capsule())
                            .position(x: editorPoint.x * proxy.size.width, y: editorPoint.y * proxy.size.height)
                    }
                    .contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                        var x = min(0.96, max(0.04, value.location.x / proxy.size.width))
                        var y = min(0.92, max(0.08, value.location.y / proxy.size.height))
                        if abs(x - 0.5) < 0.025 { x = 0.5 }
                        if abs(y - 0.5) < 0.025 { y = 0.5 }
                        editorPoint = CGPoint(x: x, y: y)
                    })
                    .focusable()
                    .onKeyPress { press in
                        let step: CGFloat = press.modifiers.contains(.shift) ? 10 : 1
                        switch press.key {
                        case .leftArrow: editorPoint.x = max(0.04, editorPoint.x - step / max(1, proxy.size.width))
                        case .rightArrow: editorPoint.x = min(0.96, editorPoint.x + step / max(1, proxy.size.width))
                        case .upArrow: editorPoint.y = max(0.08, editorPoint.y - step / max(1, proxy.size.height))
                        case .downArrow: editorPoint.y = min(0.92, editorPoint.y + step / max(1, proxy.size.height))
                        case .return:
                            settings.customPosition = CGPoint(x: editorPoint.x, y: 1 - editorPoint.y)
                        case .escape:
                            if let saved = settings.customPosition { editorPoint = CGPoint(x: saved.x, y: 1 - saved.y) }
                            else { editorPoint = CGPoint(x: 0.5, y: 0.5) }
                        default: return .ignored
                        }
                        return .handled
                    }
                }
                .frame(height: 100)
                HStack {
                    Button("settings.saveCustomPosition") { settings.customPosition = CGPoint(x: editorPoint.x, y: 1 - editorPoint.y) }
                    Button("settings.resetPosition", role: .destructive) { settings.customPosition = nil; settings.horizontal = "center"; settings.vertical = "bottom" }
                    Spacer()
                    Button("settings.preview") { coordinator.tips.show(.copy, force: true) }
                }
            }
        }
        .formStyle(.grouped)
    }

    private var systemPane: some View {
        Form {
            Section("settings.permissions") {
                LabeledContent("settings.inputMonitoring", value: coordinator.permissionGranted ? String(localized: "status.granted") : String(localized: "status.notGranted"))
                if coordinator.permissionGranted && !coordinator.monitoringActive {
                    Text("status.tapFailed").foregroundStyle(.orange)
                }
                Text("settings.inputDisclosure").font(.footnote).foregroundStyle(.secondary)
                HStack {
                    Button("permission.request") { coordinator.requestPermission() }
                    Button("permission.openSettings") { PermissionsManager.openInputMonitoringSettings() }
                }
            }
            Section("settings.system") {
                Picker("settings.language", selection: $settings.language) {
                    Text("language.system").tag("system")
                    Text("language.chinese").tag("zh-Hans")
                    Text("language.english").tag("en")
                }
                Toggle("settings.launchAtLogin", isOn: Binding(get: { LaunchAtLoginManager.isEnabled }, set: { value in
                    do { try LaunchAtLoginManager.setEnabled(value) } catch { launchError = error.localizedDescription }
                }))
                LabeledContent("app.about", value: "macOS 26+ · SwiftUI")
            }
        }
        .formStyle(.grouped)
        .onAppear(perform: coordinator.refreshPermission)
    }
}
