//
//  SearchView.swift
//  OSRS Wiki
//
//  Created on iOS development session
//

import SwiftUI
import UIKit

struct SearchView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: osrsThemeManager
    @Environment(\.osrsTheme) var osrsTheme
    @StateObject private var viewModel = SearchViewModel()
    @StateObject private var speechManager = osrsSpeechRecognitionManager()
    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool
    
    var body: some View {
        NavigationStack(path: $appState.searchNavigationPath) {
            VStack(spacing: 0) {
                // Search input section
                searchInputSection
                
                // Content section
                contentSection
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.large)
            .background(.osrsBackground)
            .onAppear {
                // Set up navigation callback
                viewModel.navigateToArticle = { title, url in
                    appState.navigateToArticle(title: title, url: url)
                }
                
                // Set up voice search callbacks
                setupVoiceSearch()
                
                // Auto-focus search when switching to this tab (matches Android behavior)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isSearchFocused = true
                    
                    // Force keyboard to appear like Android's showSoftInput
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        UIApplication.shared.sendAction(#selector(UIResponder.becomeFirstResponder), to: nil, from: nil, for: nil)
                    }
                }
            }
            .onDisappear {
                // Clean up speech recognition when leaving the view
                speechManager.cleanup()
            }
            .navigationDestination(for: NavigationDestination.self) { destination in
                switch destination {
                case .search:
                    DedicatedSearchView()
                        .environmentObject(appState)
                        .environment(\.osrsTheme, osrsTheme)
                case .article(let articleDestination):
                    ArticleView(pageTitle: articleDestination.title, pageUrl: articleDestination.url)
                        .environmentObject(appState)
                        .environment(\.osrsTheme, osrsTheme)
                }
            }
        }
    }
    
    private var searchInputSection: some View {
        VStack(spacing: 12) {
            // Main search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.osrsPlaceholderColor)
                
                TextField("Search OSRS Wiki", text: $searchText)
                    .focused($isSearchFocused)
                    .textFieldStyle(PlainTextFieldStyle())
                    .foregroundStyle(.osrsPrimaryTextColor)
                    .onChange(of: searchText) { _, newValue in
                        viewModel.currentQuery = newValue
                    }
                    .onSubmit {
                        performSearch()
                    }
                    .onTapGesture {
                        // Force focus and keyboard when tapped (matches Android behavior)
                        isSearchFocused = true
                        
                        // Additional keyboard forcing - similar to Android's showSoftInput
                        DispatchQueue.main.async {
                            UIApplication.shared.sendAction(#selector(UIResponder.becomeFirstResponder), to: nil, from: nil, for: nil)
                        }
                    }
                
                if !searchText.isEmpty {
                    Button(action: clearSearch) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.osrsSecondaryTextColor)
                    }
                }
                
                osrsVoiceSearchButton(
                    action: {
                        speechManager.startVoiceRecognition()
                    },
                    state: speechManager.currentState
                )
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .frame(height: 36)
            .background(.osrsSearchBoxBackgroundColor)
            .cornerRadius(18)
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
        .alert("Voice Search Error", isPresented: .constant(speechManager.errorMessage != nil)) {
            Button("OK") {
                speechManager.errorMessage = nil
            }
        } message: {
            if let errorMessage = speechManager.errorMessage {
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
                    .foregroundStyle(.osrsSecondaryTextColor)
                
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
                        .background(.osrsSearchBoxBackgroundColor)
                        .foregroundStyle(.osrsSecondaryTextColor)
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
                .listRowBackground(osrsTheme.surface)
            } else {
                ForEach(viewModel.searchHistory) { historyItem in
                    HistoryRowView(historyItem: ThemedHistoryItem(
                        pageTitle: historyItem.displayTitle,
                        pageUrl: historyItem.pageUrl.absoluteString,
                        snippet: historyItem.description,
                        timestamp: historyItem.visitedDate,
                        source: 1
                    )) {
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
        .scrollContentBackground(.hidden)
        .background(.osrsBackground)
    }
    
    private var searchResultsSection: some View {
        VStack(spacing: 0) {
            List {
                ForEach(viewModel.searchResults) { result in
                    SearchResultRowView(result: ThemedSearchResult(
                        title: result.displayTitle,
                        snippet: result.rawSnippet, // Use raw HTML snippet for highlighting
                        description: result.namespace,
                        url: result.url.absoluteString,
                        thumbnailUrl: result.thumbnailUrl,
                        pageId: nil
                    ), searchQuery: searchText) {
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
                                .tint(osrsTheme.primary)
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
                    .listRowBackground(osrsTheme.surface)
                    .onAppear {
                        Task {
                            await viewModel.loadMoreResults()
                        }
                    }
                }
            }
            .listStyle(PlainListStyle())
            .scrollContentBackground(.hidden)
            .background(.osrsBackground)
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
    
    private func setupVoiceSearch() {
        speechManager.configure(
            onResult: { result in
                // Set the search text and perform search
                searchText = result
                viewModel.currentQuery = result
                performSearch()
            },
            onPartialResult: { partialResult in
                // Show real-time transcription in search field
                if !partialResult.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    searchText = partialResult
                    viewModel.currentQuery = partialResult
                }
            },
            onError: { errorMessage in
                // Error handling is managed by the speech manager's published errorMessage
                print("Voice search error: \(errorMessage)")
            }
        )
    }
}

#Preview {
    SearchView()
        .environmentObject(AppState())
        .environmentObject(osrsThemeManager.preview)
        .environment(\.osrsTheme, osrsLightTheme())
}