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
    
    private let searchRepository = SearchRepository()
    private let historyRepository = HistoryRepository()
    private var cancellables = Set<AnyCancellable>()
    
    // Navigation callback - will be set by the view
    var navigateToArticle: ((String, URL) -> Void)?
    
    init() {
        loadSearchHistory()
        loadRecentSearches()
    }
    
    func performSearch(query: String) async {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        isSearching = true
        errorMessage = nil
        
        do {
            searchResults = try await searchRepository.search(query: query)
        } catch {
            errorMessage = "Search failed: \(error.localizedDescription)"
            searchResults = []
        }
        
        isSearching = false
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
    let thumbnailUrl: URL?
    let namespace: String?
    let score: Double?
    
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