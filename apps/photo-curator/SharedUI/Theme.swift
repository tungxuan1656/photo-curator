import SwiftUI

/// Brand design tokens extracted directly from the application icon (`app-icon-regular.png`).
///
/// Features a multi-stop sunset gradient flowing from golden amber down to deep ruby crimson,
/// anchored by the signature raspberry coral red accent.
enum AppTheme {
    /// Golden amber glow from the top-left of the icon (#FED462).
    static let warmAmber = Color(red: 0.996, green: 0.831, blue: 0.384)

    /// Sunset coral transition color (#FD694B).
    static let sunsetCoral = Color(red: 0.992, green: 0.412, blue: 0.294)

    /// Signature raspberry coral accent matching the icon cover and checkmark badge (#FB3751).
    static let brandAccent = Color(red: 0.984, green: 0.216, blue: 0.318)

    /// Deep ruby crimson from the bottom-right of the icon (#CB074B).
    static let deepRuby = Color(red: 0.796, green: 0.027, blue: 0.294)

    /// Full sunset linear gradient matching the app icon background orientation.
    static let sunsetGradient = LinearGradient(
        colors: [warmAmber, sunsetCoral, brandAccent, deepRuby],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Subtle glow variant for card headers, icons, and hero backgrounds.
    static let subtleGlowGradient = LinearGradient(
        colors: [warmAmber.opacity(0.3), sunsetCoral.opacity(0.2), brandAccent.opacity(0.15)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Warm hero card overlay that preserves content legibility over arbitrary photo backgrounds.
    static let heroCardOverlay = LinearGradient(
        colors: [Color.clear, Color.black.opacity(0.45), Color.black.opacity(0.85)],
        startPoint: .center,
        endPoint: .bottom
    )
}

extension Color {
    static var curatorAccent: Color {
        AppTheme.brandAccent
    }

    static var curatorWarmAmber: Color {
        AppTheme.warmAmber
    }

    static var curatorSunsetCoral: Color {
        AppTheme.sunsetCoral
    }

    static var curatorDeepRuby: Color {
        AppTheme.deepRuby
    }
}

extension ShapeStyle where Self == LinearGradient {
    static var curatorSunset: LinearGradient {
        AppTheme.sunsetGradient
    }

    static var curatorSubtleGlow: LinearGradient {
        AppTheme.subtleGlowGradient
    }
}
