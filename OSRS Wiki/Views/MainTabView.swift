//
//  MainTabView.swift
//  OSRS Wiki
//
//  Created on iOS development session
//

import SwiftUI

struct MainTabView: View {
    @StateObject private var appState = AppState()
    
    var body: some View {
        TabView(selection: $appState.selectedTab) {
            // News Tab
            NewsView()
                .tabItem {
                    Image(systemName: appState.selectedTab == .news ? 
                          TabItem.news.selectedIconName : TabItem.news.iconName)
                    Text(TabItem.news.title)
                }
                .tag(TabItem.news)
                .accessibilityLabel(TabItem.news.accessibilityLabel)
            
            // Map Tab
            MapView()
                .tabItem {
                    Image(systemName: appState.selectedTab == .map ? 
                          TabItem.map.selectedIconName : TabItem.map.iconName)
                    Text(TabItem.map.title)
                }
                .tag(TabItem.map)
                .accessibilityLabel(TabItem.map.accessibilityLabel)
            
            // Search Tab
            SearchView()
                .tabItem {
                    Image(systemName: appState.selectedTab == .search ? 
                          TabItem.search.selectedIconName : TabItem.search.iconName)
                    Text(TabItem.search.title)
                }
                .tag(TabItem.search)
                .accessibilityLabel(TabItem.search.accessibilityLabel)
            
            // Saved Tab
            SavedPagesView()
                .tabItem {
                    Image(systemName: appState.selectedTab == .saved ? 
                          TabItem.saved.selectedIconName : TabItem.saved.iconName)
                    Text(TabItem.saved.title)
                }
                .tag(TabItem.saved)
                .accessibilityLabel(TabItem.saved.accessibilityLabel)
            
            // More Tab
            MoreView()
                .tabItem {
                    Image(systemName: appState.selectedTab == .more ? 
                          TabItem.more.selectedIconName : TabItem.more.iconName)
                    Text(TabItem.more.title)
                }
                .tag(TabItem.more)
                .accessibilityLabel(TabItem.more.accessibilityLabel)
        }
        .environmentObject(appState)
        .preferredColorScheme(appState.currentTheme.colorScheme)
        .onChange(of: appState.selectedTab) { _, newTab in
            appState.setSelectedTab(newTab)
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
}

#Preview {
    MainTabView()
}