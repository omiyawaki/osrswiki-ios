//
//  OSRSTypography.swift
//  OSRS Wiki
//
//  Created for iOS typography theming to match Android system
//  Comprehensive OSRS typography with Alegreya and system fonts
//

import SwiftUI

// MARK: - OSRS Typography Extensions

extension Font {
    // MARK: - Display Text (Major headings, hero text)
    
    /// Display style using Alegreya Bold - 32pt equivalent
    static let osrsDisplay = Font.custom("Alegreya-Bold", size: 32)
    
    // MARK: - Headlines (Section headers, major navigation)
    
    /// Headline style using Alegreya Bold - 28pt equivalent
    static let osrsHeadline = Font.custom("Alegreya-Bold", size: 28)
    
    // MARK: - Titles (Card titles, page titles, important text)
    
    /// Title style using Alegreya Regular - 20pt equivalent
    static let osrsTitle = Font.custom("Alegreya-Regular", size: 20)
    
    /// Title Bold style using Alegreya Bold - 20pt equivalent
    static let osrsTitleBold = Font.custom("Alegreya-Bold", size: 20)
    
    /// List title style using Alegreya Medium - 20pt equivalent
    static let osrsListTitle = Font.custom("Alegreya-Medium", size: 20)
    
    /// List title bold style using Alegreya Bold - 20pt equivalent
    static let osrsListTitleBold = Font.custom("Alegreya-Bold", size: 20)
    
    // MARK: - Body Text (Article content, descriptions, longer text)
    
    /// Body text using system font - 16pt equivalent
    static let osrsBody = Font.system(size: 16, weight: .regular)
    
    /// Body medium using system font - 14pt equivalent
    static let osrsBodyMedium = Font.system(size: 14, weight: .regular)
    
    /// Body small using system font - 12pt equivalent
    static let osrsBodySmall = Font.system(size: 12, weight: .regular)
    
    /// Body large using system font - 16pt equivalent
    static let osrsBodyLarge = Font.system(size: 16, weight: .regular)
    
    // MARK: - UI Labels (Buttons, navigation, short UI text)
    
    /// Label medium using system font - 14pt equivalent
    static let osrsLabel = Font.system(size: 14, weight: .medium)
    
    /// Label large using system font - 18pt equivalent
    static let osrsLabelLarge = Font.system(size: 18, weight: .medium)
    
    /// Label bold using system font - 14pt equivalent
    static let osrsLabelBold = Font.system(size: 14, weight: .bold)
    
    // MARK: - Caption Text (Metadata, timestamps, auxiliary info)
    
    /// Caption text using system font - 12pt equivalent
    static let osrsCaption = Font.system(size: 12, weight: .regular)
    
    // MARK: - Monospace (Code, technical text)
    
    /// Monospace text using system monospace - 14pt equivalent
    static let osrsMono = Font.system(size: 14, weight: .regular, design: .monospaced)
    
    /// Monospace bold text using system monospace - 14pt equivalent
    static let osrsMonoBold = Font.system(size: 14, weight: .bold, design: .monospaced)
    
    /// Monospace small text using system monospace - 12pt equivalent
    static let osrsMonoSmall = Font.system(size: 12, weight: .regular, design: .monospaced)
    
    /// Monospace large text using system monospace - 16pt equivalent
    static let osrsMonoLarge = Font.system(size: 16, weight: .regular, design: .monospaced)
    
    // MARK: - Small Caps Styles (Using Alegreya SC when available)
    
    /// Navigation small caps using Alegreya SC - 12pt equivalent
    static let osrsNavigationSmallCaps = Font.custom("Alegreya SC", size: 12)
    
    /// Section header small caps using Alegreya SC Bold - 24pt equivalent
    static let osrsSectionHeaderSmallCaps = Font.custom("Alegreya SC", size: 24).weight(.bold)
    
    /// Metadata small caps using Alegreya SC - 12pt equivalent
    static let osrsMetadataSmallCaps = Font.custom("Alegreya SC", size: 12)
    
    /// Button small caps using Alegreya SC - 13pt equivalent
    static let osrsButtonSmallCaps = Font.custom("Alegreya SC", size: 13)
    
    /// Tag small caps using Alegreya SC - 13pt equivalent
    static let osrsTagSmallCaps = Font.custom("Alegreya SC", size: 13)
    
    // MARK: - UI Specific Styles
    
    /// Search bar text using system font - 16pt equivalent
    static let osrsSearchBar = Font.system(size: 16, weight: .regular)
    
    /// Navigation text using system font - 12pt equivalent
    static let osrsNavigation = Font.system(size: 12, weight: .regular)
    
    /// UI Navigation text using system font - 14pt equivalent
    static let osrsUINavigation = Font.system(size: 14, weight: .medium)
    
    /// UI Button text using system font - 12pt equivalent
    static let osrsUIButton = Font.system(size: 12, weight: .regular)
    
    /// UI Hint text using system font - 16pt equivalent
    static let osrsUIHint = Font.system(size: 16, weight: .regular)
    
    /// UI Form Label text using system font - 14pt equivalent
    static let osrsUIFormLabel = Font.system(size: 14, weight: .medium)
    
    /// UI Helper text using system font - 12pt equivalent
    static let osrsUIHelper = Font.system(size: 12, weight: .regular)
    
    /// UI Toolbar text using system font - 18pt equivalent
    static let osrsUIToolbar = Font.system(size: 18, weight: .medium)
    
    // MARK: - Preference Styles
    
    /// Preference title text using system font - 16pt equivalent
    static let osrsPreferenceTitle = Font.system(size: 16, weight: .regular)
    
    /// Preference summary text using system font - 13pt equivalent
    static let osrsPreferenceSummary = Font.system(size: 13, weight: .regular)
}

// MARK: - Typography Style Helpers

extension Text {
    /// Apply OSRS display style with proper line spacing
    func osrsDisplayStyle() -> some View {
        self
            .font(.osrsDisplay)
            .lineSpacing(8) // 1.2 line height equivalent
    }
    
    /// Apply OSRS headline style with proper line spacing
    func osrsHeadlineStyle() -> some View {
        self
            .font(.osrsHeadline)
            .lineSpacing(6) // 1.2 line height equivalent
    }
    
    /// Apply OSRS title style with proper line spacing
    func osrsTitleStyle() -> some View {
        self
            .font(.osrsTitle)
            .lineSpacing(6) // 1.3 line height equivalent
    }
    
    /// Apply OSRS body style with proper line spacing
    func osrsBodyStyle() -> some View {
        self
            .font(.osrsBody)
            .lineSpacing(3) // 1.2 line height equivalent
    }
    
    /// Apply OSRS small caps style with proper spacing
    func osrsSmallCapsStyle() -> some View {
        self
            .font(.osrsNavigationSmallCaps)
            .tracking(0.5) // Letter spacing equivalent
            .textCase(.uppercase)
    }
    
    /// Apply OSRS monospace style with proper line spacing
    func osrsMonoStyle() -> some View {
        self
            .font(.osrsMono)
            .lineSpacing(6) // 1.4 line height equivalent
    }
}

// MARK: - Typography Environment

/// Typography environment key for consistent theming
struct OSRSTypographyKey: EnvironmentKey {
    static let defaultValue = true // Enable OSRS typography by default
}

extension EnvironmentValues {
    var osrsTypography: Bool {
        get { self[OSRSTypographyKey.self] }
        set { self[OSRSTypographyKey.self] = newValue }
    }
}

// MARK: - Font Registration Helper

/// Helper to register custom fonts if needed
struct OSRSFontRegistrar {
    /// Register Alegreya fonts for OSRS theming
    /// Note: Fonts should be added to app bundle and Info.plist
    static func registerFonts() {
        // Custom font registration logic if needed
        // This would typically be called in AppDelegate or SceneDelegate
        print("📝 OSRS Typography: Custom fonts should be registered in app bundle")
    }
    
    /// Check if custom fonts are available
    static func areCustomFontsAvailable() -> Bool {
        let alegreyaAvailable = UIFont(name: "Alegreya-Regular", size: 16) != nil
        let alegreyaSCAvailable = UIFont(name: "Alegreya SC", size: 16) != nil
        
        if !alegreyaAvailable || !alegreyaSCAvailable {
            print("⚠️ OSRS Typography: Custom fonts not available, falling back to system fonts")
            return false
        }
        
        return true
    }
    
    /// Get fallback fonts for OSRS styles when custom fonts aren't available
    static func fallbackFont(for style: OSRSFontStyle) -> Font {
        switch style {
        case .display, .headline:
            return .system(.title, design: .serif, weight: .bold)
        case .title, .listTitle:
            return .system(.title2, design: .serif, weight: .medium)
        case .smallCaps:
            return .system(.caption, design: .default, weight: .medium)
        case .body:
            return .system(.body, design: .default, weight: .regular)
        case .mono:
            return .system(.body, design: .monospaced, weight: .regular)
        }
    }
}

// MARK: - Font Style Enumeration

enum OSRSFontStyle {
    case display
    case headline
    case title
    case listTitle
    case body
    case smallCaps
    case mono
}

// MARK: - Typography Preview Helper

#if DEBUG
struct OSRSTypographyPreview: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Group {
                    Text("Display Style")
                        .osrsDisplayStyle()
                        .foregroundStyle(.osrsOnSurface)
                    
                    Text("Headline Style")
                        .osrsHeadlineStyle()
                        .foregroundStyle(.osrsOnSurface)
                    
                    Text("Title Style")
                        .osrsTitleStyle()
                        .foregroundStyle(.osrsOnSurface)
                    
                    Text("Body Text Style - This shows how longer content looks with proper line spacing and the selected font family.")
                        .osrsBodyStyle()
                        .foregroundStyle(.osrsOnSurface)
                    
                    Text("Small Caps Style")
                        .osrsSmallCapsStyle()
                        .foregroundStyle(.osrsOnSurfaceVariant)
                    
                    Text("Monospace Style - Code and technical text")
                        .osrsMonoStyle()
                        .foregroundStyle(.osrsOnSurface)
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Font Availability Status:")
                        .font(.headline)
                        .foregroundStyle(.osrsOnSurface)
                    
                    Text("Custom fonts available: \(OSRSFontRegistrar.areCustomFontsAvailable() ? "✅ Yes" : "❌ No")")
                        .font(.caption)
                        .foregroundStyle(.osrsOnSurfaceVariant)
                    
                    Text("Using system font fallbacks when custom fonts are unavailable")
                        .font(.caption)
                        .foregroundStyle(.osrsOnSurfaceVariant)
                }
            }
            .padding()
        }
        .navigationTitle("OSRS Typography")
        .background(.osrsBackground)
    }
}

#Preview {
    NavigationView {
        OSRSTypographyPreview()
            .environmentObject(OSRSThemeManager.preview)
            .environment(\.osrsTheme, OSRSLightTheme())
    }
}
#endif