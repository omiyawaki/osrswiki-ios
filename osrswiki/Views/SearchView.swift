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
            ZStack {
                // Full-screen background to prevent white areas
                Color(osrsTheme.background)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Search input section
                    searchInputSection
                    
                    // Content section
                    contentSection
                }
            }
            .ignoresSafeArea(.keyboard) // Prevent keyboard avoidance padding
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                // Set up navigation callback
                viewModel.navigateToArticle = { title, url, searchResult in
                    // Dismiss keyboard before navigation to prevent blank area
                    isSearchFocused = false
                    dismissKeyboard()
                    
                    if let searchResult = searchResult {
                        // Use rich navigation with metadata for search results
                        appState.navigateToArticle(
                            title: title,
                            url: url,
                            snippet: searchResult.description,
                            thumbnailUrl: searchResult.thumbnailUrl
                        )
                    } else {
                        // Fallback to simple navigation
                        appState.navigateToArticle(title: title, url: url)
                    }
                }
                
                // Set up voice search callbacks
                setupVoiceSearch()
                
                // Focus immediately when tab appears
                isSearchFocused = true
            }
            .onDisappear {
                // Dismiss keyboard to prevent blank area when navigating back
                isSearchFocused = false
                dismissKeyboardWithLayoutUpdate()
                
                // Clean up speech recognition when leaving the view
                speechManager.cleanup()
            }
            .dismissKeyboardOnDisappear()
            .navigationDestination(for: NavigationDestination.self) { destination in
                switch destination {
                case .search:
                    DedicatedSearchView()
                        .environmentObject(appState)
                        .environment(\.osrsTheme, osrsTheme)
                case .article(let articleDestination):
                    ArticleView(
                        pageTitle: articleDestination.title,
                        pageUrl: articleDestination.url,
                        snippet: articleDestination.snippet,
                        thumbnailUrl: articleDestination.thumbnailUrl
                    )
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
                // Show empty state when no search text (history now belongs in History tab)
                emptySearchState
            } else if viewModel.isSearching && viewModel.searchResults.isEmpty {
                // Show loading during initial search
                ProgressView("Searching...")
                    .progressViewStyle(CircularProgressViewStyle())
                    .tint(.osrsPrimaryColor)
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
    
    private var emptySearchState: some View {
        VStack(spacing: 24) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 60))
                .foregroundStyle(.osrsSecondaryTextColor)
            
            Text("Search OSRS Wiki")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(.osrsPrimaryTextColor)
            
            Text("Enter a search term to find articles, items, quests, and more.")
                .font(.body)
                .foregroundStyle(.osrsSecondaryTextColor)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            if !viewModel.recentSearches.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Recent Searches")
                        .font(.headline)
                        .foregroundStyle(.osrsPrimaryTextColor)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(viewModel.recentSearches.prefix(8), id: \.self) { search in
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
                .padding(.horizontal, 20)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.osrsBackground)
    }
    
    private var searchResultsSection: some View {
        VStack(spacing: 0) {
            List {
                // CRASH FIX: Use stable IDs and pre-processed data to prevent dequeuing crashes
                ForEach(viewModel.searchResults, id: \.id) { result in
                    let themedResult = ThemedSearchResult(
                        title: result.displayTitle,
                        snippet: result.rawSnippet,
                        description: result.namespace,
                        url: result.url.absoluteString,
                        thumbnailUrl: result.thumbnailUrl,
                        pageId: Int(result.id), // Use SearchResult.id converted to Int
                        searchQuery: searchText // FUNCTIONALITY RESTORE: Pass search query for highlighting
                    )
                    
                    SearchResultRowView(result: themedResult) {
                        // Dismiss keyboard before selecting result
                        isSearchFocused = false
                        dismissKeyboard()
                        viewModel.selectSearchResult(result)
                        viewModel.addToRecentSearches(searchText)
                    }
                    .id(themedResult.id) // CRASH FIX: Use ThemedSearchResult's stable ID
                }
                
                // FIXED: Load more section with proper state management to prevent cell conflicts
                if viewModel.hasMoreResults && !viewModel.isSearching {
                    // Only show load more when not actively searching to prevent state conflicts
                    HStack {
                        Spacer()
                        Button("Load More Results") {
                            // Prevent multiple simultaneous load operations
                            guard !viewModel.isSearching else { return }
                            Task { @MainActor in
                                await viewModel.loadMoreResults()
                            }
                        }
                        .disabled(viewModel.isSearching) // Prevent conflicts during loading
                        .foregroundStyle(viewModel.isSearching ? Color.gray : Color(osrsTheme.primary))
                        Spacer()
                    }
                    .padding()
                    .listRowBackground(osrsTheme.surface)
                    // FIXED: Use consistent ID that doesn't change during updates
                    .id("load-more-section")
                } else if viewModel.isSearching && viewModel.hasMoreResults {
                    // Show loading indicator in separate section to prevent ID conflicts
                    HStack {
                        Spacer()
                        ProgressView("Loading more results...")
                            .scaleEffect(0.8)
                            .tint(osrsTheme.primary)
                        Spacer()
                    }
                    .padding()
                    .listRowBackground(osrsTheme.surface)
                    .id("loading-more-section")
                }
            }
            .listStyle(PlainListStyle())
            .scrollContentBackground(.hidden)
            .background(.osrsBackground)
            // FIXED: Remove animation on count changes that can cause cell dequeue issues
            // Animation during rapid updates can cause SwiftUI to lose track of cells
        }
    }
    
    private func performSearch() {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        // Add to recent searches when user explicitly submits
        viewModel.addToRecentSearches(searchText)
        
        // FIXED: Add slight delay to ensure UI state is consistent before starting search
        Task {
            // Brief delay to let any pending UI updates complete
            try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
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