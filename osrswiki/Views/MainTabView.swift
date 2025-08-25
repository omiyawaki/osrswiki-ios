//
//  MainTabView.swift
//  OSRS Wiki
//
//  Created on iOS development session
//

import SwiftUI

struct MainTabView: View {
    @StateObject private var appState = AppState()
    @EnvironmentObject var themeManager: osrsThemeManager
    @State private var hasStartedBackgroundGeneration = false
    
    var body: some View {
        TabView(selection: $appState.selectedTab) {
            Group {
                newsTab
                savedTab
                searchTab
                mapTab
                moreTab
            }
            .toolbarBackground(Color(themeManager.currentTheme.surface), for: .tabBar)
            .toolbarBackground(.visible, for: .tabBar)
        }
        .tint(Color(themeManager.currentTheme.primaryTextColor)) // Selected color
        .accentColor(Color(themeManager.currentTheme.bottomNavInactiveColor)) // Unselected color
        .environmentObject(appState)
        // Note: themeManager is now injected at app level in osrswikiApp.swift
        .environment(\.osrsTheme, themeManager.currentTheme)
        .preferredColorScheme(.light)  // TDD: Force light mode for testing
        .onAppear {
            // TDD: Force light theme for testing
            themeManager.setTheme(.osrsLight)
            
            // DEBUG: Extract actual colors for testing
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                ColorExtractor.exportColorsToJSON(themeManager: themeManager)
            }
        }
        .onChange(of: appState.selectedTab) { _, newTab in
            appState.setSelectedTab(newTab)
        }
        // Add horizontal gesture support for tab navigation  
        .osrsHorizontalGestures(
            isEnabled: !appState.isInArticle, // Only enable when not in article (ArticleView handles its own gestures)
            onBackGesture: {
                // Back gesture in main interface - no action (iOS doesn't have system back in main tabs)
                print("[MainTabView] Back gesture ignored in main interface")
            },
            onSidebarGesture: {
                // Left swipe in main interface - could open a settings panel or search
                // For now, just switch to search tab as a logical action
                print("[MainTabView] Sidebar gesture - switching to search tab")
                appState.setSelectedTab(.search)
            }
        )
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            // Update system color scheme when app becomes active
            let currentSystemScheme: ColorScheme = UITraitCollection.current.userInterfaceStyle == .dark ? .dark : .light
            themeManager.updateSystemColorScheme(currentSystemScheme)
        }
        .onAppear {
            // Start background tasks only once after main interface is loaded
            // PRIORITY: MapLibre preloading (essential for map performance)
            if !hasStartedBackgroundGeneration {
                hasStartedBackgroundGeneration = true
                print("🔄 Main interface loaded - starting essential background tasks...")
                Task { @MainActor in
                    // 🗺️ ESSENTIAL: Map preloading (eliminates pixelated loading)
                    print("🚀 PRIORITY: Starting MapLibre background preloading...")
                    await osrsBackgroundMapPreloader.shared.preloadMapInBackground()
                    
                    // DISABLED: Background preview generation to prevent automatic Varrock ArticleView creation
                    // This was causing unwanted entries in history during app startup
                    // TODO: Re-enable with option to exclude from history tracking
                    print("🚀 Background preview generation disabled to prevent history contamination")
                    // await osrsBackgroundPreviewManager.shared.preGenerateAllPreviews()
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
    
    // MARK: - Manual Tab Color Management (iOS 18 Compatible)
    
    
    // MARK: - Tab Views
    
    private var newsTab: some View {
        NavigationStack {
            NewsView()
        }
        .tabItem {
            Image(systemName: appState.selectedTab == .news ? 
                  TabItem.news.selectedIconName : TabItem.news.iconName)
                .renderingMode(.template)
            Text(TabItem.news.title)
        }
        .tag(TabItem.news)
        .accessibilityLabel(TabItem.news.accessibilityLabel)
        .accessibilityIdentifier("home_tab")
    }
    
    private var savedTab: some View {
        NavigationStack {
            SavedPagesView()
        }
        .tabItem {
            Image(systemName: appState.selectedTab == .saved ? 
                  TabItem.saved.selectedIconName : TabItem.saved.iconName)
                .renderingMode(.template)
            Text(TabItem.saved.title)
        }
        .tag(TabItem.saved)
        .accessibilityLabel(TabItem.saved.accessibilityLabel)
        .accessibilityIdentifier("saved_tab")
    }
    
    private var searchTab: some View {
        NavigationStack {
            HistoryView()
        }
        .tabItem {
            Image(systemName: appState.selectedTab == .search ? 
                  TabItem.search.selectedIconName : TabItem.search.iconName)
                .renderingMode(.template)
            Text(TabItem.search.title)
        }
        .tag(TabItem.search)
        .accessibilityLabel(TabItem.search.accessibilityLabel)
        .accessibilityIdentifier("search_tab")
    }
    
    private var mapTab: some View {
        NavigationStack {
            MapView()
        }
        .tabItem {
            Image(systemName: appState.selectedTab == .map ? 
                  TabItem.map.selectedIconName : TabItem.map.iconName)
                .renderingMode(.template)
            Text(TabItem.map.title)
        }
        .tag(TabItem.map)
        .accessibilityLabel(TabItem.map.accessibilityLabel)
        .accessibilityIdentifier("map_tab")
    }
    
    private var moreTab: some View {
        NavigationStack {
            MoreView()
        }
        .tabItem {
            Image(systemName: appState.selectedTab == .more ? 
                  TabItem.more.selectedIconName : TabItem.more.iconName)
                .renderingMode(.template)
            Text(TabItem.more.title)
        }
        .tag(TabItem.more)
        .accessibilityLabel(TabItem.more.accessibilityLabel)
        .accessibilityIdentifier("more_tab")
    }
}

#Preview {
    MainTabView()
        .environmentObject(osrsThemeManager.preview)
}

