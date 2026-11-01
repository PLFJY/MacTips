import Foundation

struct TipSequenceCounter {
    private(set) var currentKind: TipKind?
    private(set) var isVisible = false
    private(set) var count = 0

    mutating func show(_ kind: TipKind) -> Int {
        count = isVisible && currentKind == kind ? count + 1 : 1
        currentKind = kind
        isVisible = true
        return count
    }

    mutating func hide() {
        isVisible = false
        currentKind = nil
        count = 0
    }
}
