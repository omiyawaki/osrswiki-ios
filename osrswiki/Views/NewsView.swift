//
//  NewsView.swift
//  OSRS Wiki
//
//  Created on iOS development session
//

import SwiftUI

struct NewsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: osrsThemeManager
    @Environment(\.osrsTheme) var osrsTheme
    @StateObject private var viewModel = NewsViewModel()
    
    var body: some View {
        NavigationStack(path: $appState.navigationPath) {
            ScrollView {
                LazyVStack(spacing: 16) {
                    // Search bar at top (matches Android)
                    SearchBarView(placeholder: "Search OSRS Wiki") {
                        // Navigate to search when tapped
                        appState.setSelectedTab(.search)
                    }
                    .padding(.horizontal)
                    
                    // News content
                    if viewModel.isLoading {
                        ProgressView("Loading news...")
                            .frame(maxWidth: .infinity, minHeight: 200)
                    } else if viewModel.newsItems.isEmpty {
                        EmptyStateView(
                            iconName: "newspaper",
                            title: "No News Available",
                            subtitle: "Check back later for OSRS updates"
                        )
                    } else {
                        ForEach(viewModel.newsItems) { newsItem in
                            NewsCardView(newsItem: newsItem) {
                                // Navigate to article using native webviewer
                                if let url = newsItem.url {
                                    appState.navigateToArticle(title: newsItem.title, url: url)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("OSRS Wiki")
                        .font(.osrsDisplay)
                        .foregroundStyle(.osrsOnSurface)
                        .onAppear {
                            // Print actual font being used
                            let testFont = UIFont(name: "Alegreya-Bold", size: 32)
                            print("🔍 FONT TEST - Alegreya-Bold available: \(testFont != nil)")
                            if let font = testFont {
                                print("   Font family: '\(font.familyName)' name: '\(font.fontName)'")
                            }
                            
                            // Test what .osrsDisplay actually resolves to
                            print("🔍 FONT TEST - .osrsDisplay should be using: Alegreya-Bold")
                            print("🔍 FONT TEST - Available Alegreya fonts:")
                            for family in UIFont.familyNames.sorted() {
                                if family.lowercased().contains("alegreya") {
                                    print("   Family: \(family)")
                                    for fontName in UIFont.fontNames(forFamilyName: family) {
                                        print("     Font: \(fontName)")
                                    }
                                }
                            }
                        }
                }
            }
            .refreshable {
                await viewModel.refresh()
            }
            .background(.osrsBackground)
            .navigationDestination(for: ArticleDestination.self) { destination in
                ArticleView(pageTitle: destination.title, pageUrl: destination.url)
            }
        }
        .task {
            await viewModel.loadNews()
        }
    }
}

struct SearchBarView: View {
    let placeholder: String
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.osrsOnSurfaceVariant)
                
                Text(placeholder)
                    .foregroundStyle(.osrsOnSurfaceVariant)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Spacer()
            }
            .padding()
            .background(.osrsSurfaceVariant)
            .cornerRadius(10)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct EmptyStateView: View {
    let iconName: String
    let title: String
    let subtitle: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: iconName)
                .font(.system(size: 48))
                .foregroundStyle(.osrsOnSurfaceVariant)
            
            VStack(spacing: 8) {
                Text(title)
                    .font(.osrsHeadline)
                    .foregroundStyle(.osrsOnSurface)
                
                Text(subtitle)
                    .font(.osrsBody)
                    .foregroundStyle(.osrsOnSurfaceVariant)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 200)
    }
}

#Preview {
    NewsView()
        .environmentObject(AppState())
        .environmentObject(osrsThemeManager.preview)
        .environment(\.osrsTheme, osrsLightTheme())
}