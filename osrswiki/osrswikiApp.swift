//
//  OSRS_WikiApp.swift
//  OSRS Wiki
//
//  Created by Osamu Miyawaki on 7/29/25.
//

import SwiftUI

@main
struct osrswikiApp: App {
    @StateObject private var themeManager = osrsThemeManager()
    
    init() {
        // Register custom fonts when app starts
        print("🚀 App starting...")
        osrsFontRegistrar.registerFonts()
        print("✅ Font registration completed")
        
        // Note: Removed complex tile pre-warming service
        // Simple loading state approach is more effective and less jarring
    }
    
    var body: some Scene {
        WindowGroup {
            CustomMainTabView()
                .environmentObject(themeManager)
                // GLOBAL APP THEMING - This cascades to ALL UI components
                .tint(Color(themeManager.currentTheme.primary))
                .accentColor(Color(themeManager.currentTheme.primary))
                // Update global theming when theme changes
                .onChange(of: themeManager.currentTheme.primary) { _, _ in
                    updateGlobalTheming()
                }
                .onAppear {
                    // Initialize global theming when app starts
                    updateGlobalTheming()
                    // Pre-warm keyboard on app launch to eliminate first-show delay
                    KeyboardPrewarmer.shared.prewarmKeyboard()
                }
        }
    }
    
    /// Configure comprehensive global theming that applies to ALL UI components
    private func updateGlobalTheming() {
        let primaryColor = UIColor(themeManager.currentTheme.primary)
        
        print("🎨 [GLOBAL THEMING] Applying comprehensive app-wide theming")
        print("🎨 [GLOBAL THEMING] Primary color: \(primaryColor)")
        
        // COMPREHENSIVE UI COMPONENT THEMING
        // This ensures EVERY component uses our theme colors by default
        
        // Navigation Bars
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = UIColor(themeManager.currentTheme.surface)
        navAppearance.titleTextAttributes = [.foregroundColor: UIColor(themeManager.currentTheme.onSurface)]
        navAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor(themeManager.currentTheme.onSurface)]
        
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance  
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().tintColor = primaryColor // This fixes back buttons globally
        
        // Tab Bars
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()
        tabAppearance.backgroundColor = UIColor(themeManager.currentTheme.surface)
        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance
        UITabBar.appearance().tintColor = primaryColor
        
        // Progress Views - Global styling
        UIProgressView.appearance().tintColor = primaryColor
        UIProgressView.appearance().trackTintColor = UIColor(themeManager.currentTheme.surfaceVariant)
        
        // Activity Indicators
        UIActivityIndicatorView.appearance().color = primaryColor
        
        // Switches (Toggles)  
        UISwitch.appearance().onTintColor = primaryColor
        UISwitch.appearance().thumbTintColor = UIColor(themeManager.currentTheme.surface)
        
        // Sliders
        UISlider.appearance().tintColor = primaryColor
        UISlider.appearance().thumbTintColor = primaryColor
        
        // Segmented Controls (Pickers)
        UISegmentedControl.appearance().selectedSegmentTintColor = primaryColor
        UISegmentedControl.appearance().setTitleTextAttributes([
            .foregroundColor: UIColor(themeManager.currentTheme.onPrimary)
        ], for: .selected)
        UISegmentedControl.appearance().setTitleTextAttributes([
            .foregroundColor: UIColor(themeManager.currentTheme.onSurface)  
        ], for: .normal)
        
        // Steppers
        UIStepper.appearance().tintColor = primaryColor
        
        // Page Controls  
        UIPageControl.appearance().currentPageIndicatorTintColor = primaryColor
        UIPageControl.appearance().pageIndicatorTintColor = UIColor(themeManager.currentTheme.surfaceVariant)
        
        // Search Bars
        UISearchBar.appearance().tintColor = primaryColor
        
        // Refresh Controls
        UIRefreshControl.appearance().tintColor = primaryColor
        
        print("🎨 [GLOBAL THEMING] Comprehensive theming applied to all UI components")
    }
}
