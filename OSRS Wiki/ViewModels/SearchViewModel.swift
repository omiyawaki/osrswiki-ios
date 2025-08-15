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
    @Published var searchHistory: [HistoryItem] = []
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
    var navigateToArticle: ((String, URL) -> Void)?
    
    init() {
        loadSearchHistory()
        loadRecentSearches()
        setupSearchDebouncing()
    }
    
    private func setupSearchDebouncing() {
        // Immediate search trigger for truly live results like Android
        $currentQuery
            .removeDuplicates()
            .sink { [weak self] query in
                print("🔍 SearchViewModel: Query changed to '\(query)'")
                Task {
                    await self?.performSearch(query: query, isNewSearch: true)
                }
            }
            .store(in: &cancellables)
            
        // Optional: Keep a longer debounced version for API efficiency
        $currentQuery
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] query in
                // This could be used for more expensive operations
                print("🔍 SearchViewModel: Debounced query: '\(query)'")
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
        
        if isNewSearch {
            searchOffset = 0
            searchResults = []
            errorMessage = nil
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
                    return 
                }
                
                print("🔍 SearchViewModel: Got \(response.results.count) results, total: \(response.totalCount)")
                
                if isNewSearch {
                    searchResults = response.results
                } else {
                    searchResults.append(contentsOf: response.results)
                }
                
                hasMoreResults = response.hasMore
                totalResultCount = response.totalCount
                searchOffset += response.results.count
                
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
        // Add to history
        let historyItem = HistoryItem(
            id: UUID().uuidString,
            pageTitle: result.title,
            pageUrl: result.url,
            visitedDate: Date(),
            thumbnailUrl: result.thumbnailUrl,
            description: result.description
        )
        
        historyRepository.addToHistory(historyItem)
        loadSearchHistory()
        
        // Navigate to article view within the app
        navigateToArticle?(result.title, result.url)
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
    
    func deleteHistoryItems(at indexSet: IndexSet) {
        for index in indexSet {
            let item = searchHistory[index]
            historyRepository.removeFromHistory(item.id)
        }
        loadSearchHistory()
    }
    
    private func loadSearchHistory() {
        searchHistory = historyRepository.getHistory()
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
    let description: String?
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

struct HistoryRowView: View {
    let historyItem: HistoryItem
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Thumbnail or icon
                AsyncImage(url: historyItem.thumbnailUrl) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Image(systemName: "doc.text")
                        .foregroundColor(.secondary)
                }
                .frame(width: 40, height: 40)
                .background(Color(.systemGray6))
                .cornerRadius(6)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(historyItem.displayTitle)
                        .font(.body)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    HStack {
                        Text(historyItem.timeAgo)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if let description = historyItem.description {
                            Text("• \(description)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct SearchResultRowView: View {
    let result: SearchResult
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Thumbnail or icon
                AsyncImage(url: result.thumbnailUrl) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Image(systemName: "doc.text")
                        .foregroundColor(.secondary)
                }
                .frame(width: 48, height: 48)
                .background(Color(.systemGray6))
                .cornerRadius(8)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.displayTitle)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    if let description = result.description {
                        Text(description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)
                    }
                    
                    if let namespace = result.namespace {
                        Text(namespace)
                            .font(.caption)
                            .foregroundColor(.accentColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
                
                Spacer()
                
                Image(systemName: "arrow.up.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}