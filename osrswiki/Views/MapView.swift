//
//  MapView.swift
//  OSRS Wiki
//
//  MapLibre Native implementation for OSRS map
//

import SwiftUI

struct MapView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        NavigationStack(path: $appState.mapNavigationPath) {
            osrsMapLibreView()
                .navigationDestination(for: NavigationDestination.self) { destination in
                    switch destination {
                    case .search:
                        DedicatedSearchView()
                            .environmentObject(appState)
                    case .article(let articleDestination):
                        ArticleView(pageTitle: articleDestination.title, pageUrl: articleDestination.url)
                            .environmentObject(appState)
                    }
                }
        }
    }
}

#Preview {
    MapView()
        .environmentObject(AppState())
        .environmentObject(osrsThemeManager.preview)
        .environment(\.osrsTheme, osrsLightTheme())
}