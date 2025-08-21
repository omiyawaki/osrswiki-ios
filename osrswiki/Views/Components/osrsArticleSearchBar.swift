//
//  osrsArticleSearchBar.swift
//  osrswiki
//
//  Created on iOS search bar UI session
//

import SwiftUI

/// A reusable search bar component that matches the Android article page design
struct osrsArticleSearchBar: View {
    @Environment(\.osrsTheme) var osrsTheme
    @State private var isSearchPresented = false
    @State private var isMenuPresented = false
    @State private var searchText = ""
    @EnvironmentObject var appState: AppState
    @StateObject private var speechManager = osrsSpeechRecognitionManager()
    
    let onBackAction: () -> Void
    let onMenuAction: () -> Void
    let onVoiceSearchAction: (() -> Void)?
    
    init(
        onBackAction: @escaping () -> Void,
        onMenuAction: @escaping () -> Void,
        onVoiceSearchAction: (() -> Void)? = nil
    ) {
        self.onBackAction = onBackAction
        self.onMenuAction = onMenuAction
        self.onVoiceSearchAction = onVoiceSearchAction
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Back button
            Button(action: onBackAction) {
                Image(systemName: "chevron.left")
                    .foregroundStyle(osrsTheme.primaryTextColor)
                    .font(.system(size: 18, weight: .medium))
                    .frame(width: 44, height: 44)
            }
            
            // Search bar container
            Button(action: {
                appState.navigateToSearch()
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(osrsTheme.placeholderColor)
                        .font(.system(size: 16))
                    
                    Text("Search OSRS Wiki")
                        .foregroundStyle(osrsTheme.placeholderColor)
                        .font(.system(size: 16))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Voice search button - always show for consistency
                    osrsVoiceSearchButton(
                        action: {
                            if let voiceSearchAction = onVoiceSearchAction {
                                voiceSearchAction()
                            } else {
                                speechManager.startVoiceRecognition()
                            }
                        },
                        state: speechManager.currentState
                    )
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .frame(height: 36)
                .background(osrsTheme.searchBoxBackgroundColor)
                .cornerRadius(18)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 8)
            
            // Menu button (more options)
            Button(action: onMenuAction) {
                Image(systemName: "ellipsis")
                    .foregroundStyle(osrsTheme.primaryTextColor)
                    .font(.system(size: 18, weight: .medium))
                    .frame(width: 44, height: 44)
                    .rotationEffect(.degrees(90))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(osrsTheme.surface)
    }
}

#Preview {
    VStack {
        osrsArticleSearchBar(
            onBackAction: {},
            onMenuAction: {},
            onVoiceSearchAction: {}
        )
        Spacer()
    }
    .environmentObject(AppState())
    .environment(\.osrsTheme, osrsLightTheme())
}