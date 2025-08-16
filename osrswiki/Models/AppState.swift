//
//  AppState.swift
//  OSRS Wiki
//
//  Created on iOS development session
//

import SwiftUI
import Combine

@MainActor
class AppState: ObservableObject {
    @Published var selectedTab: TabItem = .news
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    // Navigation state
    @Published var navigationPath = NavigationPath()
    
    init() {
        loadUserPreferences()
    }
    
    private func loadUserPreferences() {
        // Load saved tab preference
        if let savedTab = UserDefaults.standard.object(forKey: "selected_tab") as? String,
           let tab = TabItem(rawValue: savedTab) {
            selectedTab = tab
        }
    }
    
    func saveUserPreferences() {
        UserDefaults.standard.set(selectedTab.rawValue, forKey: "selected_tab")
    }
    
    func setSelectedTab(_ tab: TabItem) {
        selectedTab = tab
        saveUserPreferences()
    }
    
    func showError(_ message: String) {
        errorMessage = message
    }
    
    func clearError() {
        errorMessage = nil
    }
    
    // Article navigation methods
    func navigateToArticle(title: String, url: URL) {
        let destination = ArticleDestination(title: title, url: url)
        navigationPath.append(destination)
    }
    
    func navigateBack() {
        if !navigationPath.isEmpty {
            navigationPath.removeLast()
        }
    }
}

// Navigation destinations
struct ArticleDestination: Hashable {
    let title: String
    let url: URL
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(title)
        hasher.combine(url)
    }
}