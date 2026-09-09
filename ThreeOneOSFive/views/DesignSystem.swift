import SwiftUI

enum AppTheme {
    // Exact Stealth Cyber Theme matching Reference UI
    static let stealthBg = Color(red: 0.04, green: 0.045, blue: 0.055)            // #0A0B0E Deep Matte Black
    static let stealthCard = Color(red: 0.068, green: 0.072, blue: 0.088)         // #111216 Matte Charcoal Card
    static let stealthCardBorder = Color.white.opacity(0.07)                      // Subtle Card Border
    static let stealthInnerCard = Color(red: 0.052, green: 0.055, blue: 0.07)    // #0D0E12 Inner Sub-box
    static let stealthInnerBorder = Color.white.opacity(0.045)
    static let stealthButton = Color(red: 0.082, green: 0.086, blue: 0.11)       // #15161C Interactive Button
    static let stealthButtonBorder = Color.white.opacity(0.06)
    static let stealthPlayButton = Color(red: 0.086, green: 0.09, blue: 0.118)   // #16171E Play Button
    static let stealthPlayBorder = Color.white.opacity(0.12)
    
    // Status & Accent
    static let emeraldActive = Color(red: 1.0, green: 0.23, blue: 0.36)           // #FF3B5C Cyber Crimson / Neon Red
    static let greenBadgeBg = Color(red: 0.22, green: 0.04, blue: 0.07)          // Dark Crimson Badge Background
    static let greenBadgeBorder = Color(red: 1.0, green: 0.23, blue: 0.36).opacity(0.35)
    static let accent = Color(red: 1.0, green: 0.23, blue: 0.36)                 // Primary Crimson Red Accent
    static let secondaryAccent = Color(red: 1.0, green: 0.42, blue: 0.52)        // Bright Crimson
    static let purpleAccent = Color(red: 0.85, green: 0.15, blue: 0.35)            // Neon Red-Purple
    
    // Typography Colors
    static let mutedText = Color(red: 0.50, green: 0.53, blue: 0.60)              // #7E8494 Secondary Grey
    static let subtext = Color(red: 0.68, green: 0.71, blue: 0.78)                // #AEB4C6 Light Muted
    static let primaryText = Color.white
    
    // Legacy support aliases
    static let pageBackground = stealthBg
    static let consoleBackground = stealthInnerCard
    static let glassSurface = stealthCard
    static let glassBorder = stealthCardBorder
    static let referenceCard = stealthInnerCard
    static let pageInset: CGFloat = 16
    static let rowIconSize: CGFloat = 17
    static let rowIconFrame: CGFloat = 28
    static let fileRowIconSize: CGFloat = 17
    static let fileRowIconFrame: CGFloat = 30
    static let fileRowHeight: CGFloat = 60
    static let appIconSize: CGFloat = 32
    static let emptyIconSize: CGFloat = 30
    static let selectionIconSize: CGFloat = 18
}

struct AppRowIcon: View {
    let systemName: String
    var tint: Color = AppTheme.emeraldActive
    var symbolSize: CGFloat = AppTheme.rowIconSize
    var frameSize: CGFloat = AppTheme.rowIconFrame

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(tint.opacity(0.12))
            Image(systemName: systemName)
                .font(.system(size: symbolSize, weight: .medium))
                .foregroundStyle(tint)
        }
        .frame(width: frameSize, height: frameSize)
        .accessibilityHidden(true)
    }
}

struct AppSearchField: View {
    @Binding var text: String
    let prompt: String
    let clearLabel: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppTheme.mutedText)
                .accessibilityHidden(true)

            TextField(prompt, text: $text)
                .font(.body)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppTheme.mutedText)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(clearLabel)
            }
        }
        .padding(.horizontal, 11)
        .frame(minHeight: 36)
        .background(
            AppTheme.stealthInnerCard,
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
        .padding(.horizontal, AppTheme.pageInset)
        .padding(.vertical, 8)
        .background(AppTheme.stealthBg)
    }
}

struct AppLogo: View {
    var size: CGFloat = 44

    var body: some View {
        Group {
            if let icon = UIImage(named: "UDINLogo")
                ?? UIImage(named: "ZRYXLogo")
                ?? UIImage(named: "AppIcon-1024")
                ?? UIImage(named: "AppIcon60x60") {
                Image(uiImage: icon)
                    .resizable()
                    .scaledToFit()
            } else {
                Text("UDIN")
                    .font(.system(size: size * 0.45, weight: .black, design: .default))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppTheme.stealthCard)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
        .accessibilityHidden(true)
    }
}
