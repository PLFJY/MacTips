import Foundation
import Combine

@MainActor
final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()
    private let defaults: UserDefaults
    private var isLoading = true

    @Published var showAnyCopy = true { didSet { save() } }
    @Published var showCopy = true { didSet { save() } }
    @Published var showPaste = true { didSet { save() } }
    @Published var showCut = true { didSet { save() } }
    @Published var showCapsLock = true { didSet { save() } }
    @Published var showCount = true { didSet { save() } }
    @Published var showMenuBarIcon = true { didSet { save() } }
    @Published var displaySeconds = 2.0 { didSet { save() } }
    @Published var animationSpeed = 1.0 { didSet { save() } }
    @Published var horizontal = "center" { didSet { save() } }
    @Published var vertical = "bottom" { didSet { save() } }
    @Published var followsMouse = false { didSet { save() } }
    @Published var language = "system" { didSet { save() } }
    @Published var customPosition: CGPoint? { didSet { save() } }
    var activeLocale: Locale { language == "system" ? .current : Locale(identifier: language) }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        showAnyCopy = defaults.object(forKey: "showAnyCopy") as? Bool ?? true
        showCopy = defaults.object(forKey: "showCopy") as? Bool ?? true
        showPaste = defaults.object(forKey: "showPaste") as? Bool ?? true
        showCut = defaults.object(forKey: "showCut") as? Bool ?? true
        showCapsLock = defaults.object(forKey: "showCapsLock") as? Bool ?? true
        showCount = defaults.object(forKey: "showCount") as? Bool ?? true
        showMenuBarIcon = defaults.object(forKey: "showMenuBarIcon") as? Bool ?? true
        displaySeconds = defaults.object(forKey: "displaySeconds") as? Double ?? 2
        animationSpeed = defaults.object(forKey: "animationSpeed") as? Double ?? 1
        horizontal = defaults.string(forKey: "horizontal") ?? "center"
        vertical = defaults.string(forKey: "vertical") ?? "bottom"
        followsMouse = defaults.bool(forKey: "followsMouse")
        language = defaults.string(forKey: "language") ?? "system"
        if let x = defaults.object(forKey: "customX") as? Double,
           let y = defaults.object(forKey: "customY") as? Double { customPosition = CGPoint(x: x, y: y) }
        isLoading = false
    }

    func enabled(_ kind: TipKind) -> Bool {
        switch kind {
        case .copy: showCopy
        case .paste: showPaste
        case .cut: showCut
        case .capsLock: showCapsLock
        }
    }

    private func save() {
        guard !isLoading else { return }
        defaults.set(showAnyCopy, forKey: "showAnyCopy")
        defaults.set(showCopy, forKey: "showCopy")
        defaults.set(showPaste, forKey: "showPaste")
        defaults.set(showCut, forKey: "showCut")
        defaults.set(showCapsLock, forKey: "showCapsLock")
        defaults.set(showCount, forKey: "showCount")
        defaults.set(showMenuBarIcon, forKey: "showMenuBarIcon")
        defaults.set(displaySeconds, forKey: "displaySeconds")
        defaults.set(animationSpeed, forKey: "animationSpeed")
        defaults.set(horizontal, forKey: "horizontal")
        defaults.set(vertical, forKey: "vertical")
        defaults.set(followsMouse, forKey: "followsMouse")
        defaults.set(language, forKey: "language")
        defaults.set(customPosition?.x, forKey: "customX")
        defaults.set(customPosition?.y, forKey: "customY")
    }
}
