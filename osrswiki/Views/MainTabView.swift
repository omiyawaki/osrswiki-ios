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
        .accentColor(Color(themeManager.currentTheme.primary))
        .toolbarBackground(themeManager.currentTheme.surface, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarColorScheme(themeManager.currentColorScheme == .dark ? .dark : .light, for: .tabBar)
        .tint(themeManager.currentTheme.primary)
        .onChange(of: appState.selectedTab) { _, newTab in
            appState.setSelectedTab(newTab)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            // Update system color scheme when app becomes active
            let currentSystemScheme: ColorScheme = UITraitCollection.current.userInterfaceStyle == .dark ? .dark : .light
            themeManager.updateSystemColorScheme(currentSystemScheme)
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
        .fullScreenCover(isPresented: $appState.showingFullScreenArticle) {
            if let destination = appState.fullScreenArticleDestination {
                NavigationStack {
                    ArticleView(pageTitle: destination.title, pageUrl: destination.url)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarLeading) {
                                Button("Done") {
                                    appState.closeFullScreenArticle()
                                }
                            }
                        }
                }
                .environmentObject(appState)
                .environmentObject(themeManager)
                .environment(\.osrsTheme, themeManager.currentTheme)
                .preferredColorScheme(themeManager.currentColorScheme)
            }
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