import SwiftUI

enum FiddleheadTheme {
    // MARK: - Sepia Palette

    /// Deep warm brown background — like aged parchment in low light
    static let background = Color(red: 0.094, green: 0.078, blue: 0.063) // #18140F
    /// Slightly lifted surface — card/section background
    static let surface = Color(red: 0.129, green: 0.110, blue: 0.090) // #211C17
    /// Hover state — warm mid-tone
    static let surfaceHover = Color(red: 0.168, green: 0.145, blue: 0.118) // #2B251E
    /// Primary text — warm off-white, like aged paper under lamplight
    static let textPrimary = Color(red: 0.878, green: 0.831, blue: 0.741) // #E0D4BD
    /// Secondary/muted text — dusty gold
    static let textSecondary = Color(red: 0.573, green: 0.529, blue: 0.447) // #928772
    /// Recording indicator — muted rust/sienna
    static let recording = Color(red: 0.780, green: 0.322, blue: 0.220) // #C75238
    /// Success/saved — sage green
    static let saved = Color(red: 0.467, green: 0.643, blue: 0.408) // #77A468
    /// Accent — warm amber for highlights, links
    static let accent = Color(red: 0.816, green: 0.647, blue: 0.325) // #D0A553
    /// Borders — subtle warm line
    static let border = Color(red: 0.878, green: 0.831, blue: 0.741).opacity(0.08)

    // MARK: - Spacing
    static let paddingSmall: CGFloat = 8
    static let paddingMedium: CGFloat = 12
    static let paddingLarge: CGFloat = 16
    static let paddingXL: CGFloat = 24

    // MARK: - Corner Radius
    static let cornerRadius: CGFloat = 6
    static let cornerRadiusLarge: CGFloat = 10

    // MARK: - Popover
    static let popoverWidth: CGFloat = 320

    // MARK: - Typography

    /// The custom font family name as registered by macOS from the .ttf files
    static let monoFontName = "GeistMono"

    /// Terminal-style monospaced font — primary UI font
    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let weightSuffix: String
        switch weight {
        case .bold, .semibold, .heavy, .black:
            weightSuffix = "-Bold"
        case .medium:
            weightSuffix = "-Medium"
        case .light, .thin, .ultraLight:
            weightSuffix = "-Light"
        default:
            weightSuffix = "-Regular"
        }
        return .custom("\(monoFontName)\(weightSuffix)", size: size)
    }

    /// Fixed-width numbers and code — uses the same Geist Mono
    static func monoFixed(_ size: CGFloat) -> Font {
        .custom("\(monoFontName)-Regular", size: size)
    }
}
