//
//  CustomMainTabView.swift
//  OSRS Wiki
//
//  Custom tab navigation to bypass iOS 18 SwiftUI TabView limitations
//  Provides perfect color control and cross-platform consistency
//

import SwiftUI

struct CustomMainTabView: View {
    @StateObject private var appState = AppState()
    @StateObject private var overlayManager = GlobalOverlayManager()
    @EnvironmentObject var themeManager: osrsThemeManager
    @State private var hasStartedBackgroundGeneration = false
    @State private var isTabBarVisible = true
    @State private var backgroundTasks: Set<Task<Void, Never>> = []
    
    var body: some View {
        ZStack {
            // Main content area
            VStack(spacing: 0) {
                // Content view based on selected tab
                Group {
                    switch appState.selectedTab {
                    case .news:
                        NavigationStack {
                            NewsView()
                        }
                    case .saved:
                        NavigationStack {
                            SavedPagesView()
                        }
                    case .search:
                        NavigationStack {
                            HistoryView()
                        }
                    case .map:
                        NavigationStack {
                            MapView()
                        }
                    case .more:
                        NavigationStack {
                            MoreView()
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Custom tab bar at bottom - extend to safe area
                if isTabBarVisible {
                    CustomTabBar()
                        .background(Color(themeManager.currentTheme.surface))
                        .ignoresSafeArea(.all, edges: .bottom) // Extend into safe area and ignore keyboard
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .ignoresSafeArea(.keyboard) // Prevent entire view from shifting for keyboard
            .environmentObject(appState)
            .environmentObject(overlayManager)
            .environment(\.osrsTheme, themeManager.currentTheme)
            .overlayManager(overlayManager) // Also provide via environment key
            
            // Global article bottom bar overlay - positioned at same coordinates as main tab bar
            if let articleBottomBar = overlayManager.articleBottomBar {
                VStack {
                    Spacer()
                    articleBottomBar
                        .background(Color(themeManager.currentTheme.surface))
                        .ignoresSafeArea(.all, edges: .bottom) // Same positioning as main tab bar, ignore keyboard
                }
            }
        }
        .preferredColorScheme(.light)  // TDD: Force light mode for testing
        .onAppear {
            // TDD: Force light theme for testing
            themeManager.setTheme(.osrsLight)
            
            // DEBUG: Extract actual colors for testing
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                ColorExtractor.exportColorsToJSON(themeManager: themeManager)
            }
            
            // Start background tasks only once after main interface is loaded
            if !hasStartedBackgroundGeneration {
                hasStartedBackgroundGeneration = true
                print("🔄 Main interface loaded - starting essential background tasks...")
                
                // Create cancellable background task
                let mapTask = Task { @MainActor in
                    // Check for cancellation before starting
                    guard !Task.isCancelled else { return }
                    
                    // 🗺️ ESSENTIAL: Map preloading (eliminates pixelated loading)
                    print("🚀 PRIORITY: Starting MapLibre background preloading...")
                    
                    // Add small delay to let UI settle first
                    try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                    
                    guard !Task.isCancelled else { return }
                    
                    await osrsBackgroundMapPreloader.shared.preloadMapInBackground()
                    
                    // Background preview generation disabled to prevent history contamination
                    print("🚀 Background preview generation disabled to prevent history contamination")
                }
                
                // Track the task so we can cancel it if needed
                backgroundTasks.insert(mapTask)
                appState.trackTask(mapTask)
            }
        }
        .onDisappear {
            // Cancel all background tasks when view disappears
            for task in backgroundTasks {
                task.cancel()
            }
            backgroundTasks.removeAll()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            // Update system color scheme when app becomes active
            let currentSystemScheme: ColorScheme = UITraitCollection.current.userInterfaceStyle == .dark ? .dark : .light
            themeManager.updateSystemColorScheme(currentSystemScheme)
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("hideCustomTabBar"))) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                isTabBarVisible = false
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("showCustomTabBar"))) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                isTabBarVisible = true
            }
        }
        .alert("Error", isPresented: .constant(appState.errorMessage != nil)) {
            Button("OK") {
                appState.clearError()
            }
        } message: {
            if let errorMessage = appState.errorMessage {
                Text(errorMessage)
            }
        }
    }
}

#Preview {
    CustomMainTabView()
        .environmentObject(osrsThemeManager.preview)
}