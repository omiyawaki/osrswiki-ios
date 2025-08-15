//
//  SavedPagesViewModel.swift
//  OSRS Wiki
//
//  Created on iOS development session
//

import SwiftUI
import Combine

@MainActor
class SavedPagesViewModel: ObservableObject {
    @Published var savedPages: [SavedPage] = []
    @Published var isLoading: Bool = false
    @Published var sortOrder: SortOrder = .date
    
    private let savedPagesRepository = SavedPagesRepository()
    
    enum SortOrder {
        case date
        case title
    }
    
    func loadSavedPages() async {
        isLoading = true
        savedPages = savedPagesRepository.getSavedPages()
        applySorting()
        isLoading = false
    }
    
    func refresh() async {
        await loadSavedPages()
    }
    
    func sortBy(_ order: SortOrder) {
        sortOrder = order
        applySorting()
    }
    
    func removeSavedPage(_ savedPage: SavedPage) {
        savedPagesRepository.removeSavedPage(savedPage.id)
        savedPages.removeAll { $0.id == savedPage.id }
    }
    
    func moveSavedPages(from: IndexSet, to: Int) {
        savedPages.move(fromOffsets: from, toOffset: to)
        // Save new order to repository
        savedPagesRepository.updateOrder(savedPages)
    }
    
    func navigateToPage(_ savedPage: SavedPage) {
        // Implementation for navigation
        UIApplication.shared.open(savedPage.url)
    }
    
    func sharePage(_ savedPage: SavedPage) {
        // Implementation for sharing
        let activityController = UIActivityViewController(
            activityItems: [savedPage.url],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityController, animated: true)
        }
    }
    
    func exportReadingList() {
        // Implementation for exporting reading list
    }
    
    func filteredSavedPages(searchText: String) -> [SavedPage] {
        if searchText.isEmpty {
            return savedPages
        }
        
        return savedPages.filter { page in
            page.title.localizedCaseInsensitiveContains(searchText) ||
            (page.description?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }
    
    private func applySorting() {
        switch sortOrder {
        case .date:
            savedPages.sort { $0.savedDate > $1.savedDate }
        case .title:
            savedPages.sort { $0.title < $1.title }
        }
    }
}

// MARK: - Models
struct SavedPage: Identifiable, Codable {
    let id: String
    let title: String
    let description: String?
    let url: URL
    let thumbnailUrl: URL?
    let savedDate: Date
    let isOfflineAvailable: Bool
    
    var displayTitle: String {
        return title.replacingOccurrences(of: "_", with: " ")
    }
}