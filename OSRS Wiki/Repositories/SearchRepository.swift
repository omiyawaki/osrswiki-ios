//
//  SearchRepository.swift
//  OSRS Wiki
//
//  Created on iOS development session
//

import Foundation

class SearchRepository {
    private let baseURL = "https://oldschool.runescape.wiki/api.php"
    
    func search(query: String) async throws -> [SearchResult] {
        // Simulate API call for now
        // In a real implementation, this would call the MediaWiki API
        
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay
        
        // Return mock search results that would match the query
        return [
            SearchResult(
                id: "1",
                title: "\(query)_potion",
                description: "A potion that provides various effects when consumed.",
                url: URL(string: "https://oldschool.runescape.wiki/w/\(query)_potion")!,
                thumbnailUrl: URL(string: "https://oldschool.runescape.wiki/images/thumb/placeholder.png/120px-placeholder.png"),
                namespace: "Main",
                score: 0.95
            ),
            SearchResult(
                id: "2",
                title: "\(query)_spell",
                description: "A magic spell that can be cast using the appropriate runes.",
                url: URL(string: "https://oldschool.runescape.wiki/w/\(query)_spell")!,
                thumbnailUrl: nil,
                namespace: "Main",
                score: 0.87
            ),
            SearchResult(
                id: "3",
                title: "\(query)_monster",
                description: "A creature found throughout Gielinor that players can fight.",
                url: URL(string: "https://oldschool.runescape.wiki/w/\(query)_monster")!,
                thumbnailUrl: URL(string: "https://oldschool.runescape.wiki/images/thumb/monster.png/120px-monster.png"),
                namespace: "Main",
                score: 0.72
            )
        ]
    }
}

class HistoryRepository {
    private let userDefaults = UserDefaults.standard
    private let historyKey = "search_history"
    
    func getHistory() -> [HistoryItem] {
        guard let data = userDefaults.data(forKey: historyKey),
              let history = try? JSONDecoder().decode([HistoryItem].self, from: data) else {
            return []
        }
        return history.sorted { $0.visitedDate > $1.visitedDate }
    }
    
    func addToHistory(_ item: HistoryItem) {
        var history = getHistory()
        
        // Remove existing entry for same page
        history.removeAll { $0.pageTitle == item.pageTitle }
        
        // Add new entry at beginning
        history.insert(item, at: 0)
        
        // Keep only last 100 entries
        if history.count > 100 {
            history = Array(history.prefix(100))
        }
        
        saveHistory(history)
    }
    
    func removeFromHistory(_ id: String) {
        var history = getHistory()
        history.removeAll { $0.id == id }
        saveHistory(history)
    }
    
    func clearHistory() {
        saveHistory([])
    }
    
    private func saveHistory(_ history: [HistoryItem]) {
        if let data = try? JSONEncoder().encode(history) {
            userDefaults.set(data, forKey: historyKey)
        }
    }
}