//
//  NewsView.swift
//  OSRS Wiki
//
//  Created on iOS development session
//

import SwiftUI

struct NewsView: View {
    @EnvironmentObject var appState: AppState
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
            .navigationTitle("OSRS Wiki")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await viewModel.refresh()
            }
            .background(appState.currentTheme.backgroundColor)
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
                    .foregroundColor(.secondary)
                
                Text(placeholder)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Spacer()
            }
            .padding()
            .background(Color(.systemGray6))
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
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
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
}