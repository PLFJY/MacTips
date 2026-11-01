import Foundation

enum TipKind: String, CaseIterable, Identifiable, Sendable {
    case copy, paste, cut, capsLock
    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .copy: "doc.on.doc"
        case .paste: "doc.on.clipboard"
        case .cut: "scissors"
        case .capsLock: "capslock"
        }
    }

    var title: String {
        switch self {
        case .copy: String(localized: "tip.copy")
        case .paste: String(localized: "tip.paste")
        case .cut: String(localized: "tip.cut")
        case .capsLock: String(localized: "tip.caps")
        }
    }
}

struct TipPresentation: Equatable, Sendable {
    var kind: TipKind
    var count: Int = 1
    var state: Bool? = nil

    var title: String {
        guard kind == .capsLock, let state else { return kind.title }
        return state ? String(localized: "tip.caps.on") : String(localized: "tip.caps.off")
    }
}
