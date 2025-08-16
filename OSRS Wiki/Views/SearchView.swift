//
//  SearchView.swift
//  OSRS Wiki
//
//  Created on iOS development session
//

import SwiftUI

struct SearchView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: OSRSThemeManager
    @Environment(\.osrsTheme) var osrsTheme
    @StateObject private var viewModel = SearchViewModel()
    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool
    
    var body: some View {
        NavigationStack(path: $appState.navigationPath) {
            VStack(spacing: 0) {
                // Search input section
                searchInputSection
                
                // Content section
                contentSection
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.large)
            .background(.osrsBackground)
            .navigationDestination(for: ArticleDestination.self) { destination in
                ArticleView(pageTitle: destination.title, pageUrl: destination.url)
            }
            .onAppear {
                // Set up navigation callback
                viewModel.navigateToArticle = { title, url in
                    appState.navigateToArticle(title: title, url: url)
                }
                
                // Auto-focus search when switching to this tab (matches Android behavior)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isSearchFocused = true
                }
            }
        }
    }
    
    private var searchInputSection: some View {
        VStack(spacing: 12) {
            // Main search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.osrsOnSurfaceVariant)
                
                TextField("Search OSRS Wiki", text: $searchText)
                    .focused($isSearchFocused)
                    .textFieldStyle(PlainTextFieldStyle())
                    .foregroundStyle(.osrsOnSurface)
                    .onChange(of: searchText) { _, newValue in
                        viewModel.currentQuery = newValue
                    }
                    .onSubmit {
                        performSearch()
                    }
                
                if !searchText.isEmpty {
                    Button(action: clearSearch) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.osrsOnSurfaceVariant)
                    }
                }
                
                Button(action: {
                    // Voice search placeholder
                    appState.showError("Voice search not yet implemented")
                }) {
                    Image(systemName: "mic")
                        .foregroundStyle(.osrsOnSurfaceVariant)
                }
            }
            .padding()
            .background(.osrsSurfaceVariant)
            .cornerRadius(10)
            .padding(.horizontal)
            
            // Recent searches or suggestions
            if searchText.isEmpty && !viewModel.recentSearches.isEmpty {
                recentSearchesSection
            }
        }
        .background(.osrsBackground)
    }
    
    private var contentSection: some View {
        Group {
            if searchText.isEmpty {
                // Show history when no search text
                historySection
            } else if viewModel.isSearching && viewModel.searchResults.isEmpty {
                // Show loading during initial search
                ProgressView("Searching...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.searchResults.isEmpty && !searchText.isEmpty && !viewModel.isSearching {
                // Show no results
                EmptyStateView(
                    iconName: "magnifyingglass",
                    title: "No Results",
                    subtitle: "Try different search terms"
                )
            } else {
                // Show search results with error handling
                searchResultsSection
            }
        }
        .alert("Search Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
            }
        }
    }
    
    private var recentSearchesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Recent Searches")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.osrsOnSurfaceVariant)
                
                Spacer()
                
                Button("Clear") {
                    viewModel.clearRecentSearches()
                }
                .font(.subheadline)
                .foregroundStyle(.osrsPrimary)
            }
            .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(viewModel.recentSearches.prefix(5), id: \.self) { search in
                        Button(search) {
                            searchText = search
                            performSearch()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.osrsSurfaceVariant)
                        .foregroundStyle(.osrsOnSurfaceVariant)
                        .cornerRadius(16)
                        .font(.subheadline)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    private var historySection: some View {
        List {
            if viewModel.searchHistory.isEmpty {
                EmptyStateView(
                    iconName: "clock",
                    title: "No Search History",
                    subtitle: "Your search history will appear here"
                )
                .listRowSeparator(.hidden)
            } else {
                ForEach(viewModel.searchHistory) { historyItem in
                    HistoryRowView(historyItem: historyItem) {
                        // Navigate to page using the article viewer
                        appState.navigateToArticle(title: historyItem.pageTitle, url: historyItem.pageUrl)
                    }
                }
                .onDelete { indexSet in
                    viewModel.deleteHistoryItems(at: indexSet)
                }
            }
        }
        .listStyle(PlainListStyle())
    }
    
    private var searchResultsSection: some View {
        VStack(spacing: 0) {
            // Results summary
            if viewModel.totalResultCount > 0 {
                HStack {
                    Text("\(viewModel.totalResultCount) results")
                        .font(.caption)
                        .foregroundStyle(.osrsOnSurfaceVariant)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(.osrsSurfaceVariant)
            }
            
            List {
                ForEach(viewModel.searchResults) { result in
                    SearchResultRowView(result: result) {
                        viewModel.selectSearchResult(result)
                        viewModel.addToRecentSearches(searchText)
                    }
                }
                
                // Load more section
                if viewModel.hasMoreResults {
                    HStack {
                        Spacer()
                        if viewModel.isSearching {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Button("Load More Results") {
                                Task {
                                    await viewModel.loadMoreResults()
                                }
                            }
                            .foregroundStyle(.osrsPrimary)
                        }
                        Spacer()
                    }
                    .padding()
                    .onAppear {
                        Task {
                            await viewModel.loadMoreResults()
                        }
                    }
                }
            }
            .listStyle(PlainListStyle())
        }
    }
    
    private func performSearch() {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        // Add to recent searches when user explicitly submits
        viewModel.addToRecentSearches(searchText)
        
        Task {
            await viewModel.performSearch(query: searchText, isNewSearch: true)
        }
    }
    
    private func clearSearch() {
        searchText = ""
        viewModel.currentQuery = ""
        viewModel.clearSearchResults()
    }
}

#Preview {
    SearchView()
        .environmentObject(AppState())
        .environmentObject(OSRSThemeManager.preview)
        .environment(\.osrsTheme, OSRSLightTheme())
}