//
//  SavedPagesRepository.swift
//  OSRS Wiki
//
//  Created on iOS development session
//

import Foundation

class SavedPagesRepository {
    private let userDefaults = UserDefaults.standard
    private let savedPagesKey = "saved_pages"
    
    func getSavedPages() -> [SavedPage] {
        guard let data = userDefaults.data(forKey: savedPagesKey),
              let savedPages = try? JSONDecoder().decode([SavedPage].self, from: data) else {
            return []
        }
        return savedPages
    }
    
    func addSavedPage(_ page: SavedPage) {
        var savedPages = getSavedPages()
        
        // Remove existing entry for same page
        savedPages.removeAll { $0.url == page.url }
        
        // Add new entry at beginning
        savedPages.insert(page, at: 0)
        
        saveSavedPages(savedPages)
    }
    
    func removeSavedPage(_ id: String) {
        var savedPages = getSavedPages()
        savedPages.removeAll { $0.id == id }
        saveSavedPages(savedPages)
    }
    
    func updateOrder(_ pages: [SavedPage]) {
        saveSavedPages(pages)
    }
    
    func clearSavedPages() {
        saveSavedPages([])
    }
    
    private func saveSavedPages(_ pages: [SavedPage]) {
        if let data = try? JSONEncoder().encode(pages) {
            userDefaults.set(data, forKey: savedPagesKey)
        }
    }
}