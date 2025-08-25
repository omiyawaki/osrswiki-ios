//
//  SearchViewModel.swift
//  OSRS Wiki
//
//  Created on iOS development session
//

import SwiftUI
import Combine

@MainActor
class SearchViewModel: ObservableObject {
    @Published var searchResults: [SearchResult] = []
    @Published var recentSearches: [String] = []
    @Published var isSearching: Bool = false
    @Published var errorMessage: String?
    @Published var hasMoreResults: Bool = false
    @Published var totalResultCount: Int = 0
    @Published var currentQuery: String = ""
    
    private let searchRepository = SearchRepository()
    private let historyRepository = HistoryRepository()
    private var cancellables = Set<AnyCancellable>()
    private var currentSearchTask: Task<Void, Never>?
    private var searchOffset = 0
    private let searchLimit = 20
    
    // Navigation callback - will be set by the view
    var navigateToArticle: ((String, URL, SearchResult?) -> Void)?
    
    init() {
        PerformanceTimer.shared.start("SearchViewModel.init")
        
        PerformanceTimer.shared.start("loadRecentSearches")
        loadRecentSearches()
        _ = PerformanceTimer.shared.end("loadRecentSearches")
        
        PerformanceTimer.shared.start("setupSearchDebouncing")
        setupSearchDebouncing()
        _ = PerformanceTimer.shared.end("setupSearchDebouncing")
        
        _ = PerformanceTimer.shared.end("SearchViewModel.init")
    }
    
    private func setupSearchDebouncing() {
        // Fixed: Use debounced search to prevent rapid API calls and UI conflicts
        $currentQuery
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main) // Faster than 500ms but prevents conflicts
            .removeDuplicates()
            .sink { [weak self] query in
                print("🔍 SearchViewModel: Debounced query changed to '\(query)'")
                Task { @MainActor in
                    await self?.performSearch(query: query, isNewSearch: true)
                }
            }
            .store(in: &cancellables)
    }
    
    func performSearch(query: String, isNewSearch: Bool = true) async {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        print("🔍 SearchViewModel: performSearch called with query '\(trimmedQuery)'")
        guard !trimmedQuery.isEmpty else {
            print("🔍 SearchViewModel: Empty query, clearing results")
            clearSearchResults()
            return
        }
        
        // Cancel previous search if it's still running
        currentSearchTask?.cancel()
        
        // CRASH FIX: Atomic state updates to prevent race conditions during list rendering
        if isNewSearch {
            await Task.yield() // Let other UI updates complete
            searchOffset = 0
            // Clear results in a separate operation to prevent rendering conflicts
            DispatchQueue.main.async { [weak self] in
                self?.searchResults = []
                self?.errorMessage = nil
            }
        }
        
        isSearching = true
        
        currentSearchTask = Task {
            do {
                print("🔍 SearchViewModel: Starting search API call for '\(trimmedQuery)'")
                
                // Debug: Test direct API call for comparison
                if trimmedQuery.lowercased() == "varrock" {
                    await searchRepository.testDirectAPICall(query: trimmedQuery)
                }
                
                let response = try await searchRepository.search(
                    query: trimmedQuery,
                    limit: searchLimit,
                    offset: searchOffset
                )
                
                guard !Task.isCancelled else { 
                    print("🔍 SearchViewModel: Search task was cancelled")
                    // CRASH FIX: Clean up state on cancellation
                    await MainActor.run {
                        isSearching = false
                    }
                    return 
                }
                
                print("🔍 SearchViewModel: Got \(response.results.count) results, total: \(response.totalCount)")
                
                // CRASH FIX: Atomic array updates to prevent list rendering conflicts
                await MainActor.run { [weak self] in
                    guard let self = self else { return }
                    
                    if isNewSearch {
                        self.searchResults = response.results
                    } else {
                        // Use batch update to prevent intermediate states
                        var updatedResults = self.searchResults
                        updatedResults.append(contentsOf: response.results)
                        self.searchResults = updatedResults
                    }
                    
                    self.totalResultCount = response.totalCount
                    self.searchOffset += response.results.count
                }
                
            } catch let error as SearchError {
                guard !Task.isCancelled else { return }
                print("🔍 SearchViewModel: SearchError: \(error.localizedDescription)")
                errorMessage = error.localizedDescription
                if isNewSearch {
                    searchResults = []
                }
            } catch {
                guard !Task.isCancelled else { return }
                print("🔍 SearchViewModel: General error: \(error.localizedDescription)")
                errorMessage = "Search failed: \(error.localizedDescription)"
                if isNewSearch {
                    searchResults = []
                }
            }
            
            isSearching = false
        }
    }
    
    func loadMoreResults() async {
        guard hasMoreResults && !isSearching && !currentQuery.isEmpty else { return }
        await performSearch(query: currentQuery, isNewSearch: false)
    }
    
    func selectSearchResult(_ result: SearchResult) {
        // Navigate to article view - history will be tracked by ArticleViewModel
        navigateToArticle?(result.title, result.url, result)
    }
    
    func addToRecentSearches(_ query: String) {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return }
        
        // Remove if already exists
        recentSearches.removeAll { $0 == trimmedQuery }
        
        // Add to beginning
        recentSearches.insert(trimmedQuery, at: 0)
        
        // Keep only last 10
        if recentSearches.count > 10 {
            recentSearches = Array(recentSearches.prefix(10))
        }
        
        saveRecentSearches()
    }
    
    func clearRecentSearches() {
        recentSearches.removeAll()
        saveRecentSearches()
    }
    
    func clearSearchResults() {
        searchResults.removeAll()
    }
    
    func navigateToPage(_ pageTitle: String) {
        // Implementation would navigate to the page
        // For now, this is a placeholder
    }
    
    
    private func loadRecentSearches() {
        if let saved = UserDefaults.standard.array(forKey: "recent_searches") as? [String] {
            recentSearches = saved
        }
    }
    
    private func saveRecentSearches() {
        UserDefaults.standard.set(recentSearches, forKey: "recent_searches")
    }
}

// MARK: - Models
struct SearchResult: Identifiable, Codable {
    let id: String
    let title: String
    let description: String? // HTML-stripped version for fallback
    let rawSnippet: String? // Raw HTML snippet with <span class="searchmatch"> tags
    let url: URL
    var thumbnailUrl: URL? // Made mutable for batch thumbnail updates
    let ns: Int? // Namespace ID to match Android exactly
    let namespace: String? // Human readable namespace
    let score: Double?
    let index: Int? // Added to preserve search ranking order
    let size: Int? // Added to match Android
    let wordcount: Int? // Added to match Android
    let timestamp: String? // Added to match Android
    
    var displayTitle: String {
        return title.replacingOccurrences(of: "_", with: " ")
    }
}

struct HistoryItem: Identifiable, Codable {
    let id: String
    let pageTitle: String
    let pageUrl: URL
    let visitedDate: Date
    let thumbnailUrl: URL?
    let description: String?
    
    var displayTitle: String {
        return pageTitle.replacingOccurrences(of: "_", with: " ")
    }
    
    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: visitedDate, relativeTo: Date())
    }
}