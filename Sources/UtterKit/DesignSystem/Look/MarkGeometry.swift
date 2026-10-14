import Foundation

/// The icon's seven bars, measured from AppIconSource.png; one unit is the spacing between bars.
/// `PillBars` draws them at pill size.
enum MarkGeometry {
    static let rest: [CGFloat] = [6.7, 3.96, 1.98, 1.19, 1.98, 3.96, 6.7]

    static func noise(_ x: Double, seed: Int) -> Double {
        func value(_ n: Double) -> Double {
            let v = sin((n + Double(seed) * 17) * 12.9898) * 43758.5453
            return v - v.rounded(.down)
        }
        let cell = x.rounded(.down), fraction = x - cell
        let eased = fraction * fraction * (3 - 2 * fraction)
        return value(cell) + (value(cell + 1) - value(cell)) * eased
    }
}
