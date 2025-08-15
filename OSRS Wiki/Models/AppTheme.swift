//
//  AppTheme.swift
//  OSRS Wiki
//
//  Created on iOS development session
//

import SwiftUI

enum AppTheme: String, CaseIterable {
    case automatic = "automatic"
    case light = "light"
    case dark = "dark"
    case osrsLight = "osrs_light"
    case osrsDark = "osrs_dark"
    
    var displayName: String {
        switch self {
        case .automatic:
            return "Automatic"
        case .light:
            return "Light"
        case .dark:
            return "Dark"
        case .osrsLight:
            return "OSRS Light"
        case .osrsDark:
            return "OSRS Dark"
        }
    }
    
    var colorScheme: ColorScheme? {
        switch self {
        case .automatic:
            return nil
        case .light, .osrsLight:
            return .light
        case .dark, .osrsDark:
            return .dark
        }
    }
    
    var isOSRSTheme: Bool {
        switch self {
        case .osrsLight, .osrsDark:
            return true
        case .automatic, .light, .dark:
            return false
        }
    }
    
    // OSRS-specific colors
    var primaryColor: Color {
        switch self {
        case .osrsLight:
            return Color(red: 0.8, green: 0.7, blue: 0.3) // OSRS gold
        case .osrsDark:
            return Color(red: 0.9, green: 0.8, blue: 0.4) // Brighter OSRS gold
        default:
            return .accentColor
        }
    }
    
    var backgroundColor: Color {
        switch self {
        case .osrsLight:
            return Color(red: 0.95, green: 0.93, blue: 0.88) // Parchment-like
        case .osrsDark:
            return Color(red: 0.1, green: 0.1, blue: 0.12) // Dark stone
        default:
            return Color(.systemBackground)
        }
    }
    
    var secondaryBackgroundColor: Color {
        switch self {
        case .osrsLight:
            return Color(red: 0.92, green: 0.89, blue: 0.82)
        case .osrsDark:
            return Color(red: 0.15, green: 0.15, blue: 0.17)
        default:
            return Color(.secondarySystemBackground)
        }
    }
    
    // Colors for WebView JavaScript injection (hex format)
    var surfaceColor: String {
        switch self {
        case .osrsLight:
            return "#F2EDE0"
        case .osrsDark:
            return "#1A1A1F"
        default:
            return colorScheme == .dark ? "#1C1C1E" : "#FFFFFF"
        }
    }
    
    var onSurfaceColor: String {
        switch self {
        case .osrsLight:
            return "#2C1810"
        case .osrsDark:
            return "#E5D5A0"
        default:
            return colorScheme == .dark ? "#FFFFFF" : "#000000"
        }
    }
    
    var primaryColorHex: String {
        switch self {
        case .osrsLight:
            return "#CDB34D"
        case .osrsDark:
            return "#E6CE66"
        default:
            return "#007AFF"
        }
    }
    
    var backgroundColorHex: String {
        switch self {
        case .osrsLight:
            return "#F2EDE0"
        case .osrsDark:
            return "#1A1A1F"
        default:
            return colorScheme == .dark ? "#000000" : "#FFFFFF"
        }
    }
}