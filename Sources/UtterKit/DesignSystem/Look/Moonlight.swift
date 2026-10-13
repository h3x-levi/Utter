import AppKit

/// One appearance of a palette: the liquid per state, the deep body, and the glass tint.
struct PillLiquidStyle: Equatable {
    var listening: SIMD3<Float>
    var handsFree: SIMD3<Float>
    var thinking: SIMD3<Float>
    var done: SIMD3<Float>
    var error: SIMD3<Float>
    var body: SIMD3<Float>
    var tint: SIMD3<Float>
    /// Ink clouding clear water rather than light in dark glass.
    var ink: Bool
}

/// The Moonlight palette, shared by the pill, the Home ribbon and onboarding.
struct PillPalette: Equatable {
    var dark: PillLiquidStyle
    var light: PillLiquidStyle

    func style(dark isDark: Bool) -> PillLiquidStyle { isDark ? dark : light }

    static let moonlight = PillPalette(
        dark: PillLiquidStyle(listening: .oklch(0.94, 0.025, 250), handsFree: .oklch(0.86, 0.07, 240),
                              thinking: .oklch(0.9, 0.012, 260), done: .oklch(0.9, 0.07, 168),
                              error: .oklch(0.8, 0.13, 70), body: .oklch(0.9, 0.02, 250),
                              tint: SIMD3(0.05, 0.058, 0.09), ink: false),
        light: PillLiquidStyle(listening: .oklch(0.6, 0.09, 250), handsFree: .oklch(0.52, 0.13, 252),
                               thinking: .oklch(0.72, 0.02, 260), done: .oklch(0.6, 0.1, 165),
                               error: .oklch(0.66, 0.15, 60), body: .oklch(0.42, 0.05, 258),
                               tint: SIMD3(0.95, 0.96, 0.975), ink: true))
}

extension SIMD3 where Scalar == Float {
    /// OKLCH (lightness, chroma, hue in degrees) to gamma-encoded sRGB.
    static func oklch(_ l: Float, _ c: Float, _ h: Float) -> SIMD3<Float> {
        let a = c * cos(h * .pi / 180), b = c * sin(h * .pi / 180)
        let lms = SIMD3(pow(l + 0.3963377774 * a + 0.2158037573 * b, 3),
                        pow(l - 0.1055613458 * a - 0.0638541728 * b, 3),
                        pow(l - 0.0894841775 * a - 1.291485548 * b, 3))
        let linear = SIMD3(4.0767416621 * lms.x - 3.3077115913 * lms.y + 0.2309699292 * lms.z,
                           -1.2684380046 * lms.x + 2.6097574011 * lms.y - 0.3413193965 * lms.z,
                           -0.0041960863 * lms.x - 0.7034186147 * lms.y + 1.707614701 * lms.z)
        func encode(_ x: Float) -> Float {
            let x = Swift.min(Swift.max(x, 0), 1)
            return x <= 0.0031308 ? 12.92 * x : 1.055 * pow(x, 1 / 2.4) - 0.055
        }
        return SIMD3(encode(linear.x), encode(linear.y), encode(linear.z))
    }

    var color: NSColor { NSColor(srgbRed: CGFloat(x), green: CGFloat(y), blue: CGFloat(z), alpha: 1) }
}
