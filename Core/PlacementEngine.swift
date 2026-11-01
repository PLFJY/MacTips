import Foundation

enum SlideDirection: Equatable {
    case left, right, up, down
    var offset: CGVector {
        switch self {
        case .left: CGVector(dx: -1, dy: 0)
        case .right: CGVector(dx: 1, dy: 0)
        case .up: CGVector(dx: 0, dy: 1)
        case .down: CGVector(dx: 0, dy: -1)
        }
    }
}

enum PlacementEngine {
    static let edgeFraction: CGFloat = 0.15

    static func origin(visibleFrame: CGRect, windowSize: CGSize, horizontal: String,
                       vertical: String, customPosition: CGPoint? = nil, margin: CGFloat = 24) -> CGPoint {
        let maxX = max(visibleFrame.minX, visibleFrame.maxX - windowSize.width)
        let maxY = max(visibleFrame.minY, visibleFrame.maxY - windowSize.height)
        if let customPosition {
            return CGPoint(x: min(maxX, max(visibleFrame.minX, visibleFrame.minX + customPosition.x * (maxX - visibleFrame.minX))),
                           y: min(maxY, max(visibleFrame.minY, visibleFrame.minY + customPosition.y * (maxY - visibleFrame.minY))))
        }
        let x = switch horizontal {
        case "left": visibleFrame.minX + margin
        case "right": visibleFrame.maxX - windowSize.width - margin
        default: visibleFrame.midX - windowSize.width / 2
        }
        let y = vertical == "top" ? visibleFrame.maxY - windowSize.height - margin : visibleFrame.minY + margin
        return CGPoint(x: min(maxX, max(visibleFrame.minX, x)), y: min(maxY, max(visibleFrame.minY, y)))
    }

    static func slideDirection(origin: CGPoint, visibleFrame: CGRect, windowSize: CGSize) -> SlideDirection {
        let center = CGPoint(x: origin.x + windowSize.width / 2, y: origin.y + windowSize.height / 2)
        let nx = (center.x - visibleFrame.minX) / visibleFrame.width
        let ny = (center.y - visibleFrame.minY) / visibleFrame.height
        return if nx < edgeFraction { .left }
        else if nx > 1 - edgeFraction { .right }
        else if ny > 1 - edgeFraction { .up }
        else { .down }
    }
}
