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
    @Published var currentTheme: AppTheme = .automatic
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    // Navigation state
    @Published var navigationPath = NavigationPath()
    
    init() {
        loadUserPreferences()
    }
    
    private func loadUserPreferences() {
        // Load saved theme preference
        if let savedTheme = UserDefaults.standard.object(forKey: "app_theme") as? String,
           let theme = AppTheme(rawValue: savedTheme) {
            currentTheme = theme
        }
        
        // Load saved tab preference
        if let savedTab = UserDefaults.standard.object(forKey: "selected_tab") as? String,
           let tab = TabItem(rawValue: savedTab) {
            selectedTab = tab
        }
    }
    
    func saveUserPreferences() {
        UserDefaults.standard.set(currentTheme.rawValue, forKey: "app_theme")
        UserDefaults.standard.set(selectedTab.rawValue, forKey: "selected_tab")
    }
    
    func setSelectedTab(_ tab: TabItem) {
        selectedTab = tab
        saveUserPreferences()
    }
    
    func setTheme(_ theme: AppTheme) {
        currentTheme = theme
        saveUserPreferences()
    }
    
    func showError(_ message: String) {
        errorMessage = message
    }
    
    func clearError() {
        errorMessage = nil
    }
}