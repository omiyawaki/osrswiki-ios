//
//  MainTabView.swift
//  OSRS Wiki
//
//  Created on iOS development session
//

import SwiftUI

struct MainTabView: View {
    @StateObject private var appState = AppState()
    @StateObject private var themeManager = osrsThemeManager()
    @State private var hasStartedBackgroundGeneration = false
    
    var body: some View {
        TabView(selection: $appState.selectedTab) {
            newsTab
            savedTab
            searchTab
            mapTab
            moreTab
        }
        .environmentObject(appState)
        .environmentObject(themeManager)
        .environment(\.osrsTheme, themeManager.currentTheme)
        .preferredColorScheme(themeManager.currentColorScheme)
        .onAppear {
            // Additional tab bar styling for iOS 18+ compatibility
            configureTabBarAppearance()
        }
        .onChange(of: themeManager.currentTheme.surface) { _, _ in
            // Update tab bar when theme changes
            DispatchQueue.main.async {
                configureTabBarAppearance()
            }
        }
        .onChange(of: themeManager.currentColorScheme) { _, _ in
            // Update tab bar when color scheme changes
            DispatchQueue.main.async {
                configureTabBarAppearance()
            }
        }
        .onChange(of: themeManager.currentTheme.primaryTextColor) { _, _ in
            // Update tab bar when primary text color changes (for tab icon/text colors)
            DispatchQueue.main.async {
                configureTabBarAppearance()
            }
        }
        .onChange(of: appState.selectedTab) { _, newTab in
            appState.setSelectedTab(newTab)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            // Update system color scheme when app becomes active
            let currentSystemScheme: ColorScheme = UITraitCollection.current.userInterfaceStyle == .dark ? .dark : .light
            themeManager.updateSystemColorScheme(currentSystemScheme)
        }
        .onAppear {
            // Start background preview generation only once after main interface is loaded
            if !hasStartedBackgroundGeneration {
                hasStartedBackgroundGeneration = true
                print("🔄 Main interface loaded - starting background preview generation...")
                Task { @MainActor in
                    await osrsBackgroundPreviewManager.shared.preGenerateAllPreviews()
                }
            }
        }
        .alert("Error", isPresented: .constant(appState.errorMessage != nil)) {
            Button("OK") {
                appState.clearError()
            }
        } message: {
            if let errorMessage = appState.errorMessage {
                Text(errorMessage)
            }
        }
    }
    
    // MARK: - Tab Bar Configuration
    
    private func configureTabBarAppearance() {
        print("🎨 [TAB BAR] Configuring tab bar appearance with theme: \(themeManager.currentTheme is osrsLightTheme ? "Light" : "Dark")")
        
        let tabBarAppearance = UITabBarAppearance()
        
        // Configure background
        tabBarAppearance.configureWithOpaqueBackground()
        tabBarAppearance.backgroundColor = UIColor(themeManager.currentTheme.surface)
        
        print("🎨 [TAB BAR] Surface color: \(UIColor(themeManager.currentTheme.surface))")
        
        // Configure item colors using Apple's recommended alpha-based approach
        // Use single base color with different alpha values for active/inactive states
        let baseTabColor = UIColor(themeManager.currentTheme.primaryTextColor)
        
        print("🎨 [TAB BAR] Base text color: \(baseTabColor)")
        
        // Inactive tabs: Same color with 40% opacity (following iOS native patterns)
        tabBarAppearance.stackedLayoutAppearance.normal.iconColor = baseTabColor.withAlphaComponent(0.4)
        tabBarAppearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: baseTabColor.withAlphaComponent(0.4)
        ]
        
        // Active tabs: Full opacity base color
        tabBarAppearance.stackedLayoutAppearance.selected.iconColor = baseTabColor
        tabBarAppearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: baseTabColor
        ]
        
        // Also configure compact layout for landscape mode
        tabBarAppearance.compactInlineLayoutAppearance.normal.iconColor = baseTabColor.withAlphaComponent(0.4)
        tabBarAppearance.compactInlineLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: baseTabColor.withAlphaComponent(0.4)
        ]
        tabBarAppearance.compactInlineLayoutAppearance.selected.iconColor = baseTabColor
        tabBarAppearance.compactInlineLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: baseTabColor
        ]
        
        // Apply appearance globally first
        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
        
        // Force refresh with more aggressive approach
        DispatchQueue.main.async { [tabBarAppearance] in
            // Force update on all current tab bars
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                for window in windowScene.windows {
                    self.updateTabBarsInView(window.rootViewController?.view)
                }
            }
        }
        
        print("🎨 [TAB BAR] Tab bar appearance configuration completed")
    }
    
    private func updateTabBarsInView(_ view: UIView?) {
        guard let view = view else { return }
        
        if let tabBar = view as? UITabBar {
            tabBar.standardAppearance = UITabBar.appearance().standardAppearance
            tabBar.scrollEdgeAppearance = UITabBar.appearance().scrollEdgeAppearance
            tabBar.setNeedsLayout()
            tabBar.layoutIfNeeded()
            print("🎨 [TAB BAR] Force updated tab bar: \(tabBar)")
        }
        
        for subview in view.subviews {
            updateTabBarsInView(subview)
        }
    }
    
    // MARK: - Tab Views
    
    private var newsTab: some View {
        NewsView()
            .tabItem {
                Image(systemName: appState.selectedTab == .news ? 
                      TabItem.news.selectedIconName : TabItem.news.iconName)
                Text(TabItem.news.title)
            }
            .tag(TabItem.news)
            .accessibilityLabel(TabItem.news.accessibilityLabel)
            .accessibilityIdentifier("home_tab")
    }
    
    private var savedTab: some View {
        SavedPagesView()
            .tabItem {
                Image(systemName: appState.selectedTab == .saved ? 
                      TabItem.saved.selectedIconName : TabItem.saved.iconName)
                Text(TabItem.saved.title)
            }
            .tag(TabItem.saved)
            .accessibilityLabel(TabItem.saved.accessibilityLabel)
            .accessibilityIdentifier("saved_tab")
    }
    
    private var searchTab: some View {
        HistoryView()
            .tabItem {
                Image(systemName: appState.selectedTab == .search ? 
                      TabItem.search.selectedIconName : TabItem.search.iconName)
                Text(TabItem.search.title)
            }
            .tag(TabItem.search)
            .accessibilityLabel(TabItem.search.accessibilityLabel)
            .accessibilityIdentifier("search_tab")
    }
    
    private var mapTab: some View {
        MapView()
            .tabItem {
                Image(systemName: appState.selectedTab == .map ? 
                      TabItem.map.selectedIconName : TabItem.map.iconName)
                Text(TabItem.map.title)
            }
            .tag(TabItem.map)
            .accessibilityLabel(TabItem.map.accessibilityLabel)
            .accessibilityIdentifier("map_tab")
    }
    
    private var moreTab: some View {
        MoreView()
            .tabItem {
                Image(systemName: appState.selectedTab == .more ? 
                      TabItem.more.selectedIconName : TabItem.more.iconName)
                Text(TabItem.more.title)
            }
            .tag(TabItem.more)
            .accessibilityLabel(TabItem.more.accessibilityLabel)
            .accessibilityIdentifier("more_tab")
    }
}

#Preview {
    MainTabView()
}