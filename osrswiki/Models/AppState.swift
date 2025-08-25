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
    
    // Task cancellation management
    private var activeTabTasks: Set<Task<Void, Never>> = []
    private var tabSwitchDebouncer: Task<Void, Never>?
    private let tabSwitchDelay: TimeInterval = 0.1 // Debounce rapid tab switches
    
    // Navigation state - separate navigation paths for each tab
    @Published var newsNavigationPath = NavigationPath()
    @Published var savedNavigationPath = NavigationPath()
    @Published var searchNavigationPath = NavigationPath()
    @Published var mapNavigationPath = NavigationPath()
    @Published var moreNavigationPath = NavigationPath()
    
    // Current tab's navigation path
    var currentNavigationPath: Binding<NavigationPath> {
        switch selectedTab {
        case .news:
            return Binding(
                get: { self.newsNavigationPath },
                set: { self.newsNavigationPath = $0 }
            )
        case .saved:
            return Binding(
                get: { self.savedNavigationPath },
                set: { self.savedNavigationPath = $0 }
            )
        case .search:
            return Binding(
                get: { self.searchNavigationPath },
                set: { self.searchNavigationPath = $0 }
            )
        case .map:
            return Binding(
                get: { self.mapNavigationPath },
                set: { self.mapNavigationPath = $0 }
            )
        case .more:
            return Binding(
                get: { self.moreNavigationPath },
                set: { self.moreNavigationPath = $0 }
            )
        }
    }
    
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
        // Cancel any pending tab switch
        tabSwitchDebouncer?.cancel()
        
        // Debounce rapid tab switches to prevent crashes
        tabSwitchDebouncer = Task { @MainActor in
            // Small delay to debounce rapid switches
            try? await Task.sleep(nanoseconds: UInt64(tabSwitchDelay * 1_000_000_000))
            
            guard !Task.isCancelled else { return }
            
            // Cancel all active tasks from previous tab
            cancelActiveTabTasks()
            
            // Actually switch the tab
            selectedTab = tab
            saveUserPreferences()
            
            // Post notification for views to cancel their operations
            NotificationCenter.default.post(name: Notification.Name("TabSwitched"), object: tab)
        }
    }
    
    func cancelActiveTabTasks() {
        // Cancel all tracked tasks
        for task in activeTabTasks {
            task.cancel()
        }
        activeTabTasks.removeAll()
        
        // Post cancellation notification
        NotificationCenter.default.post(name: Notification.Name("CancelTabOperations"), object: nil)
    }
    
    func trackTask(_ task: Task<Void, Never>) {
        activeTabTasks.insert(task)
        
        // Remove task when completed
        Task { @MainActor in
            await task.value
            activeTabTasks.remove(task)
        }
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
    
    // Article navigation methods - using NavigationStack with per-tab paths
    func navigateToArticle(title: String, url: URL) {
        let destination = ArticleDestination(title: title, url: url)
        appendToCurrentNavigationPath(NavigationDestination.article(destination))
    }
    
    // Rich navigation with metadata (for search results and enhanced history)
    func navigateToArticle(title: String, url: URL, snippet: String?, thumbnailUrl: URL?) {
        let destination = ArticleDestination(title: title, url: url, snippet: snippet, thumbnailUrl: thumbnailUrl)
        appendToCurrentNavigationPath(NavigationDestination.article(destination))
    }
    
    // URL-only navigation (like Android) - extracts title from URL
    func navigateToArticle(url: URL) {
        let destination = ArticleDestination(title: nil, url: url)
        appendToCurrentNavigationPath(NavigationDestination.article(destination))
    }
    
    // Navigate to search
    func navigateToSearch() {
        PerformanceTimer.shared.start("navigateToSearch")
        appendToCurrentNavigationPath(NavigationDestination.search)
        _ = PerformanceTimer.shared.end("navigateToSearch")
    }
    
    // Check if currently viewing an article (has navigation depth > 0)
    var isInArticle: Bool {
        return !currentNavigationPath.wrappedValue.isEmpty
    }
    
    // Navigate back
    func navigateBack() {
        removeLastFromCurrentNavigationPath()
    }
    
    // Helper to append to current tab's navigation path
    private func appendToCurrentNavigationPath(_ destination: NavigationDestination) {
        switch selectedTab {
        case .news:
            newsNavigationPath.append(destination)
        case .saved:
            savedNavigationPath.append(destination)
        case .search:
            searchNavigationPath.append(destination)
        case .map:
            mapNavigationPath.append(destination)
        case .more:
            moreNavigationPath.append(destination)
        }
    }
    
    // Helper to remove last item from current tab's navigation path
    private func removeLastFromCurrentNavigationPath() {
        switch selectedTab {
        case .news:
            if !newsNavigationPath.isEmpty {
                newsNavigationPath.removeLast()
            }
        case .saved:
            if !savedNavigationPath.isEmpty {
                savedNavigationPath.removeLast()
            }
        case .search:
            if !searchNavigationPath.isEmpty {
                searchNavigationPath.removeLast()
            }
        case .map:
            if !mapNavigationPath.isEmpty {
                mapNavigationPath.removeLast()
            }
        case .more:
            if !moreNavigationPath.isEmpty {
                moreNavigationPath.removeLast()
            }
        }
    }
    
    // Clear navigation stack for a specific tab (useful for tab switching)
    func clearNavigationPath(for tab: TabItem? = nil) {
        let targetTab = tab ?? selectedTab
        switch targetTab {
        case .news:
            newsNavigationPath = NavigationPath()
        case .saved:
            savedNavigationPath = NavigationPath()
        case .search:
            searchNavigationPath = NavigationPath()
        case .map:
            mapNavigationPath = NavigationPath()
        case .more:
            moreNavigationPath = NavigationPath()
        }
    }
}

// Navigation destinations
enum NavigationDestination: Hashable {
    case search
    case article(ArticleDestination)
}

struct ArticleDestination: Hashable {
    let title: String?  // Optional - will be extracted from URL if nil
    let url: URL
    let snippet: String?  // Optional - for rich history display
    let thumbnailUrl: URL?  // Optional - for rich history display
    
    init(title: String?, url: URL, snippet: String? = nil, thumbnailUrl: URL? = nil) {
        self.title = title
        self.url = url
        self.snippet = snippet
        self.thumbnailUrl = thumbnailUrl
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(title)
        hasher.combine(url)
        hasher.combine(snippet)
        hasher.combine(thumbnailUrl)
    }
}