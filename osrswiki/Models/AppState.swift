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
    
    // Full screen article presentation
    @Published var showingFullScreenArticle = false
    @Published var fullScreenArticleDestination: ArticleDestination?
    
    init() {
        loadUserPreferences()
        handleLaunchArguments()
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
    
    private func handleLaunchArguments() {
        let arguments = ProcessInfo.processInfo.arguments
        
        // Check for direct tab launch arguments
        // Usage: -startTab <tab_name>
        if let startTabIndex = arguments.firstIndex(of: "-startTab"),
           startTabIndex + 1 < arguments.count {
            let tabName = arguments[startTabIndex + 1]
            if let tab = TabItem(rawValue: tabName) {
                selectedTab = tab
                print("🚀 Launch argument: starting with \(tab.title) tab")
            }
        }
        
        // Check for screenshot mode (automatically takes screenshots of all tabs)
        if arguments.contains("-screenshotMode") {
            print("🧪 Screenshot mode enabled")
            // This will be handled by the screenshot automation script
        }
    }
    
    // Article navigation methods - now using full screen presentation
    func navigateToArticle(title: String, url: URL) {
        let destination = ArticleDestination(title: title, url: url)
        fullScreenArticleDestination = destination
        showingFullScreenArticle = true
    }
    
    // URL-only navigation (like Android) - extracts title from URL
    func navigateToArticle(url: URL) {
        let destination = ArticleDestination(title: nil, url: url)
        fullScreenArticleDestination = destination
        showingFullScreenArticle = true
    }
    
    // Close full screen article
    func closeFullScreenArticle() {
        showingFullScreenArticle = false
        fullScreenArticleDestination = nil
    }
    
    func navigateBack() {
        if !navigationPath.isEmpty {
            navigationPath.removeLast()
        }
    }
}

// Navigation destinations
struct ArticleDestination: Hashable {
    let title: String?  // Optional - will be extracted from URL if nil
    let url: URL
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(title)
        hasher.combine(url)
    }
}