//
//  osrsThemeManager.swift
//  OSRS Wiki
//
//  Created on iOS theming research session
//  Theme management with persistence and automatic system integration
//

import SwiftUI
import Combine

// MARK: - Theme Selection

/// Available theme options for user selection
enum osrsThemeSelection: String, CaseIterable {
    case automatic = "automatic"
    case osrsLight = "osrs_light"
    case osrsDark = "osrs_dark"
    
    var displayName: String {
        switch self {
        case .automatic:
            return "Automatic"
        case .osrsLight:
            return "OSRS Light"
        case .osrsDark:
            return "OSRS Dark"
        }
    }
    
    var description: String {
        switch self {
        case .automatic:
            return "Follows system Light/Dark mode with OSRS colors"
        case .osrsLight:
            return "Light OSRS theme with parchment backgrounds"
        case .osrsDark:
            return "Dark OSRS theme with aged parchment backgrounds"
        }
    }
    
    /// Get the theme instance based on color scheme (for automatic)
    func theme(for colorScheme: ColorScheme?) -> any osrsThemeProtocol {
        switch self {
        case .automatic:
            return colorScheme == .dark ? osrsDarkTheme() : osrsLightTheme()
        case .osrsLight:
            return osrsLightTheme()
        case .osrsDark:
            return osrsDarkTheme()
        }
    }
    
    /// Get the intended color scheme for SwiftUI's environment
    var colorScheme: ColorScheme? {
        switch self {
        case .automatic:
            return nil // Let system decide
        case .osrsLight:
            return .light
        case .osrsDark:
            return .dark
        }
    }
}

// MARK: - Theme Manager

/// Observable theme manager that handles theme selection, persistence, and system integration
@MainActor
class osrsThemeManager: ObservableObject {
    // MARK: - Published Properties
    
    /// Currently selected theme option
    @Published var selectedTheme: osrsThemeSelection = .automatic {
        didSet {
            saveThemeSelection()
            updateCurrentTheme()
        }
    }
    
    /// Current resolved theme based on selection and system state
    @Published private(set) var currentTheme: any osrsThemeProtocol = osrsLightTheme()
    
    /// Current color scheme for SwiftUI environment
    @Published private(set) var currentColorScheme: ColorScheme? = nil
    
    /// System color scheme tracking
    @Published private(set) var systemColorScheme: ColorScheme = .light
    
    // MARK: - Private Properties
    
    private let userDefaults = UserDefaults.standard
    private let themeSelectionKey = "osrs_theme_selection"
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init() {
        loadSavedTheme()
        updateCurrentTheme()
        setupSystemColorSchemeObserver()
    }
    
    // MARK: - Public Methods
    
    /// Set the theme selection and persist it
    func setTheme(_ theme: osrsThemeSelection) {
        selectedTheme = theme
    }
    
    /// Update system color scheme (called from app level)
    func updateSystemColorScheme(_ colorScheme: ColorScheme) {
        systemColorScheme = colorScheme
        updateCurrentTheme()
    }
    
    /// Get theme colors for WebView JavaScript injection
    func getWebViewColors() -> WebViewThemeColors {
        if let lightTheme = currentTheme as? osrsLightTheme {
            return WebViewThemeColors(
                surface: lightTheme.surface.toHex(),
                onSurface: lightTheme.onSurface.toHex(),
                primary: lightTheme.primary.toHex(),
                background: lightTheme.background.toHex(),
                accent: lightTheme.accent.toHex()
            )
        } else if let darkTheme = currentTheme as? osrsDarkTheme {
            return WebViewThemeColors(
                surface: darkTheme.surface.toHex(),
                onSurface: darkTheme.onSurface.toHex(),
                primary: darkTheme.primary.toHex(),
                background: darkTheme.background.toHex(),
                accent: darkTheme.accent.toHex()
            )
        } else {
            // Fallback to light theme colors
            let fallback = osrsLightTheme()
            return WebViewThemeColors(
                surface: fallback.surface.toHex(),
                onSurface: fallback.onSurface.toHex(),
                primary: fallback.primary.toHex(),
                background: fallback.background.toHex(),
                accent: fallback.accent.toHex()
            )
        }
    }
    
    // MARK: - Private Methods
    
    private func loadSavedTheme() {
        if let savedThemeRaw = userDefaults.string(forKey: themeSelectionKey),
           let savedTheme = osrsThemeSelection(rawValue: savedThemeRaw) {
            selectedTheme = savedTheme
        }
    }
    
    private func saveThemeSelection() {
        userDefaults.set(selectedTheme.rawValue, forKey: themeSelectionKey)
    }
    
    private func updateCurrentTheme() {
        let resolvedColorScheme = selectedTheme == .automatic ? systemColorScheme : nil
        currentTheme = selectedTheme.theme(for: resolvedColorScheme)
        currentColorScheme = selectedTheme.colorScheme ?? systemColorScheme
    }
    
    private func setupSystemColorSchemeObserver() {
        // Note: This will be called from the app level when system color scheme changes
        // The updateSystemColorScheme method handles the actual updates
    }
}

// MARK: - WebView Integration

/// Colors formatted for WebView JavaScript injection
struct WebViewThemeColors {
    let surface: String
    let onSurface: String
    let primary: String
    let background: String
    let accent: String
    
    /// Generate JavaScript to inject theme colors
    func generateJavaScript() -> String {
        return """
        document.documentElement.style.setProperty('--osrs-surface', '\(surface)');
        document.documentElement.style.setProperty('--osrs-on-surface', '\(onSurface)');
        document.documentElement.style.setProperty('--osrs-primary', '\(primary)');
        document.documentElement.style.setProperty('--osrs-background', '\(background)');
        document.documentElement.style.setProperty('--osrs-accent', '\(accent)');
        
        // Legacy color variables for compatibility
        document.documentElement.style.setProperty('--color-surface', '\(surface)');
        document.documentElement.style.setProperty('--color-on-surface', '\(onSurface)');
        document.documentElement.style.setProperty('--color-primary', '\(primary)');
        document.documentElement.style.setProperty('--color-background', '\(background)');
        """
    }
}

// MARK: - Color Hex Conversion

extension Color {
    /// Convert Color to hex string for WebView injection
    func toHex() -> String {
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        let rgb = Int(red * 255) << 16 | Int(green * 255) << 8 | Int(blue * 255)
        return String(format: "#%06X", rgb)
    }
}

// MARK: - Preview Support

#if DEBUG
/// Theme manager instance for SwiftUI previews
extension osrsThemeManager {
    static let preview: osrsThemeManager = {
        let manager = osrsThemeManager()
        manager.selectedTheme = .osrsLight
        return manager
    }()
    
    static let previewDark: osrsThemeManager = {
        let manager = osrsThemeManager()
        manager.selectedTheme = .osrsDark
        return manager
    }()
}
#endif