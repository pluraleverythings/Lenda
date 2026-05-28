import SwiftUI

/// Design tokens in the spirit of Dieter Rams: restrained, functional, one warm accent.
enum DR {
    // Surfaces
    static let surface = Color(.systemBackground)
    static let surfaceMuted = Color(.secondarySystemBackground)
    static let surfaceCompressed = Color(.tertiarySystemBackground)

    // Text
    static let ink = Color.primary
    static let inkSecondary = Color.secondary
    static let inkTertiary = Color(.tertiaryLabel)

    // Rules
    static let rule = Color(.separator).opacity(0.45)
    static let ruleStrong = Color(.separator)
    static let hairline: CGFloat = 0.5

    // The single functional accent — Braun-ish warm orange. Sourced from the asset
    // catalog so light/dark and override via Asset.xcassets remain easy.
    static let accent = Color.accentColor

    // Metrics
    static let dayRowHeight: CGFloat = 84
    static let dayLabelWidth: CGFloat = 60
    static let monthBarHeight: CGFloat = 40
    static let timeHeaderHeight: CGFloat = 22
    static let horizontalPadding: CGFloat = 16

    enum TypeStyle {
        static let monthInactive: Font = .system(size: 13, weight: .regular)
        static let monthActive: Font = .system(size: 13, weight: .semibold)
        static let weekday: Font = .system(size: 10, weight: .medium)
        static let dayNumber: Font = .system(size: 22, weight: .regular)
        static let dayNumberToday: Font = .system(size: 22, weight: .semibold)
        static let eventTitle: Font = .system(size: 10, weight: .medium)
        static let hourTick: Font = .system(size: 9, weight: .regular)
    }
}
