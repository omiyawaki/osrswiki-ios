//
//  HistoryRepository.swift
//  OSRS Wiki
//
//  Created on iOS webviewer implementation session
//

import Foundation

class HistoryRepository {
    private let userDefaults = UserDefaults.standard
    private let historyKey = "search_history"
    private let maxHistoryItems = 100
    
    func getHistory() -> [HistoryItem] {
        guard let data = userDefaults.data(forKey: historyKey),
              let history = try? JSONDecoder().decode([HistoryItem].self, from: data) else {
            return []
        }
        return history.sorted { $0.visitedDate > $1.visitedDate }
    }
    
    func addToHistory(_ item: HistoryItem) {
        var history = getHistory()
        
        // Remove existing item with same URL to avoid duplicates
        history.removeAll { $0.pageUrl == item.pageUrl }
        
        // Add new item at the beginning
        history.insert(item, at: 0)
        
        // Keep only the most recent items
        if history.count > maxHistoryItems {
            history = Array(history.prefix(maxHistoryItems))
        }
        
        saveHistory(history)
    }
    
    func removeFromHistory(_ itemId: String) {
        var history = getHistory()
        history.removeAll { $0.id == itemId }
        saveHistory(history)
    }
    
    func clearHistory() {
        userDefaults.removeObject(forKey: historyKey)
    }
    
    private func saveHistory(_ history: [HistoryItem]) {
        if let data = try? JSONEncoder().encode(history) {
            userDefaults.set(data, forKey: historyKey)
        }
    }
}