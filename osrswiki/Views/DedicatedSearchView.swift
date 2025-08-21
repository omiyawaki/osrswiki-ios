//
//  DedicatedSearchView.swift
//  OSRS Wiki
//
//  Dedicated search modal that matches Android SearchActivity behavior
//

import SwiftUI
import UIKit
import os.log

struct DedicatedSearchView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: osrsThemeManager
    @Environment(\.osrsTheme) var osrsTheme
    @StateObject private var viewModel = SearchViewModel()
    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Search input section (matches Android SearchActivity)
            searchInputSection
            
            // Content section
            contentSection
        }
        .navigationTitle("Search")
        .navigationBarTitleDisplayMode(.inline)
        .background(.osrsBackground)
        .tint(Color(osrsTheme.primary))
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Back") {
                    appState.navigateBack()
                }
                .foregroundStyle(Color(osrsTheme.primary))
            }
        }
        .onAppear {
            // Set up navigation callback - use NavigationStack navigation
            viewModel.navigateToArticle = { title, url in
                appState.navigateToArticle(title: title, url: url)
            }
            
            // Configure navigation bar appearance to theme the back button chevron
            configureNavigationBarAppearance()
            
            // Auto-focus search field when view appears (matches Android SearchActivity)
            DispatchQueue.main.async {
                isSearchFocused = true
            }
        }
    }
    
    private func configureNavigationBarAppearance() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(osrsTheme.surface)
        appearance.titleTextAttributes = [.foregroundColor: UIColor(osrsTheme.primaryTextColor)]
        
        // Configure back button appearance - this is the key for the chevron color
        appearance.backButtonAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor(osrsTheme.primary)]
        
        // Set the back indicator image with the theme color
        if let backImage = UIImage(systemName: "chevron.backward")?
            .withTintColor(UIColor(osrsTheme.primary), renderingMode: .alwaysOriginal) {
            appearance.setBackIndicatorImage(backImage, transitionMaskImage: backImage)
        }
        
        // Apply the appearance
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        
        print("🎨 [NAV BAR] Configured navigation bar appearance with back button color: \(UIColor(osrsTheme.primary))")
    }
    
    private var searchInputSection: some View {
        VStack(spacing: 12) {
            // Main search bar (matches Android SearchActivity style)
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.osrsPlaceholderColor)
                
                TextField("Search OSRS Wiki", text: $searchText)
                    .focused($isSearchFocused)
                    .textFieldStyle(PlainTextFieldStyle())
                    .foregroundStyle(.osrsPrimaryTextColor)
                    .tint(Color(osrsTheme.primary))
                    .autocorrectionDisabled(true)
                    .textInputAutocapitalization(.never)
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
                            .foregroundStyle(.osrsPlaceholderColor)
                    }
                }
                
                Button(action: {
                    // Voice search placeholder
                    appState.showError("Voice search not yet implemented")
                }) {
                    Image(systemName: "mic")
                        .foregroundStyle(.osrsPlaceholderColor)
                }
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
                // Show history when no search text (matches Android SearchFragment initial state)
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
                        // Use direct navigation via AppState
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
        List {
                ForEach(viewModel.searchResults) { result in
                    SearchResultRowView(result: ThemedSearchResult(
                        title: result.displayTitle,
                        snippet: result.rawSnippet,
                        description: result.namespace,
                        url: result.url.absoluteString,
                        thumbnailUrl: result.thumbnailUrl,
                        pageId: nil
                    ), searchQuery: searchText) {
                        viewModel.selectSearchResult(result)
                        viewModel.addToRecentSearches(searchText)
                        // Don't dismiss modal - let article present over search results
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
    DedicatedSearchView()
        .environmentObject(AppState())
        .environmentObject(osrsThemeManager.preview)
        .environment(\.osrsTheme, osrsLightTheme())
}