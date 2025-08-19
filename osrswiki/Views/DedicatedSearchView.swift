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
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search input section (matches Android SearchActivity)
                searchInputSection
                
                // Content section
                contentSection
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .background(.osrsBackground)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .foregroundStyle(.osrsPrimary)
                }
            }
            .onAppear {
                // Set up navigation callback
                viewModel.navigateToArticle = { title, url in
                    // Dismiss search modal first
                    isPresented = false
                    // Then navigate to article
                    appState.navigateToArticle(title: title, url: url)
                }
                
                // Auto-focus search field when modal appears (matches Android SearchActivity)
                DispatchQueue.main.async {
                    isSearchFocused = true
                }
            }
        }
    }
    
    private var searchInputSection: some View {
        VStack(spacing: 12) {
            // Main search bar (matches Android SearchActivity style)
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
                        // Dismiss modal and navigate to page
                        isPresented = false
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
                    SearchResultRowView(result: ThemedSearchResult(
                        title: result.displayTitle,
                        snippet: result.rawSnippet,
                        description: result.namespace,
                        url: result.url.absoluteString,
                        thumbnailUrl: result.thumbnailUrl,
                        pageId: nil
                    )) {
                        viewModel.selectSearchResult(result)
                        viewModel.addToRecentSearches(searchText)
                        // Dismiss modal after selection
                        isPresented = false
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
}

#Preview {
    DedicatedSearchView(isPresented: .constant(true))
        .environmentObject(AppState())
        .environmentObject(osrsThemeManager.preview)
        .environment(\.osrsTheme, osrsLightTheme())
}