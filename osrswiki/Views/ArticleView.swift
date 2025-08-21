//
//  ArticleView.swift
//  OSRS Wiki
//
//  Created on iOS webviewer implementation session
//

import SwiftUI
import WebKit

struct ArticleView: View {
    @Environment(\.osrsTheme) var osrsTheme
    @EnvironmentObject var themeManager: osrsThemeManager
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel: ArticleViewModel
    @StateObject private var speechManager = osrsSpeechRecognitionManager()
    @State private var isShowingShareSheet = false
    @State private var isShowingTableOfContents = false
    @State private var isShowingAppearanceSettings = false
    @State private var isShowingPageMenu = false
    @State private var isShowingFeedback = false
    
    let pageTitle: String?
    let pageUrl: URL
    
    init(pageTitle: String?, pageUrl: URL, collapseTablesEnabled: Bool = true) {
        self.pageTitle = pageTitle
        self.pageUrl = pageUrl
        self._viewModel = StateObject(wrappedValue: ArticleViewModel(pageUrl: pageUrl, pageTitle: pageTitle, pageId: nil, collapseTablesEnabled: collapseTablesEnabled))
        print("🏗️ ArticleView: Created with title='\(pageTitle ?? "nil")' url=\(pageUrl), collapseTables=\(collapseTablesEnabled)")
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Custom search bar instead of navigation bar
            osrsArticleSearchBar(
                onBackAction: {
                    // Navigate back using NavigationStack
                    appState.navigateBack()
                },
                onMenuAction: {
                    isShowingPageMenu = true
                },
                onVoiceSearchAction: {
                    speechManager.startVoiceRecognition()
                }
            )
            
            // Progress bar
            if viewModel.isLoading {
                ProgressView(value: viewModel.loadingProgress, total: 1.0)
                    .progressViewStyle(LinearProgressViewStyle())
                    .transition(.opacity)
            }
            
            // WebView content
            ArticleWebView(viewModel: viewModel)
                .background(Color.osrsBackgroundColor)
            
            // Bottom Action Bar - replicating Android functionality
            osrsArticleBottomBar(
                onSaveAction: {
                    viewModel.performSaveAction()
                },
                onFindInPageAction: {
                    viewModel.performFindInPageAction()
                },
                onAppearanceAction: {
                    viewModel.performAppearanceAction()
                },
                onContentsAction: {
                    isShowingTableOfContents = true
                },
                isBookmarked: viewModel.isBookmarked,
                saveState: viewModel.saveState,
                saveProgress: viewModel.saveProgress,
                hasTableOfContents: viewModel.hasTableOfContents
            )
        }
        .background(Color.osrsBackgroundColor)
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .tabBar)
            .sheet(isPresented: $isShowingShareSheet) {
                ShareSheet(items: [pageUrl])
            }
            .overlay(
                // Enhanced contents drawer with Android-style functionality
                osrsContentsDrawerSimple(
                    isPresented: $isShowingTableOfContents,
                    sections: viewModel.tableOfContents,
                    onSectionSelected: { sectionId in
                        viewModel.scrollToSection(sectionId)
                    }
                )
                .ignoresSafeArea()
            )
            .sheet(isPresented: $isShowingAppearanceSettings) {
                NavigationStack {
                    AppearanceSettingsView()
                        .environmentObject(themeManager)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Done") {
                                    isShowingAppearanceSettings = false
                                }
                            }
                        }
                }
            }
            .sheet(isPresented: $isShowingFeedback) {
                NavigationStack {
                    FeedbackView()
                        .environmentObject(themeManager)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Done") {
                                    isShowingFeedback = false
                                }
                            }
                        }
                }
            }
            .confirmationDialog("Page Options", isPresented: $isShowingPageMenu) {
                Button("Share") {
                    isShowingShareSheet = true
                }
                Button("Go to Top") {
                    scrollToTop()
                }
                Button("Copy Link") {
                    copyPageLink()
                }
                Button("Refresh Page") {
                    refreshPage()
                }
                Button("Open in Browser") {
                    openInBrowser()
                }
                Button("View Page History") {
                    viewPageHistory()
                }
                Button("Report Issue") {
                    reportIssue()
                }
                Button("Cancel", role: .cancel) { }
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
                    viewModel.clearError()
                }
            } message: {
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                }
            }
            .alert("Voice Search Error", isPresented: .constant(speechManager.errorMessage != nil)) {
                Button("OK") {
                    speechManager.errorMessage = nil
                }
            } message: {
                if let errorMessage = speechManager.errorMessage {
                    Text(errorMessage)
                }
            }
        .onAppear {
            print("📱 ArticleView: onAppear called - loading article")
            viewModel.loadArticle(theme: osrsTheme)
        }
        .onChange(of: osrsTheme as? osrsLightTheme != nil) { _, _ in
            // Reload with new theme when theme changes
            viewModel.loadArticle(theme: osrsTheme)
        }
        .onReceive(NotificationCenter.default.publisher(for: .showAppearanceSettings)) { _ in
            isShowingAppearanceSettings = true
        }
        .onDisappear {
            // Clean up speech recognition when leaving the view
            speechManager.cleanup()
        }
    }
    
    // MARK: - Menu Action Helpers
    
    private func scrollToTop() {
        viewModel.webView?.evaluateJavaScript("window.scrollTo(0, 0);") { _, _ in
            // Could add haptic feedback or visual confirmation here
        }
    }
    
    private func copyPageLink() {
        let pasteboard = UIPasteboard.general
        pasteboard.string = pageUrl.absoluteString
        // Could show a toast or alert here to confirm the copy action
    }
    
    private func refreshPage() {
        viewModel.loadArticle(theme: osrsTheme)
    }
    
    private func openInBrowser() {
        UIApplication.shared.open(pageUrl)
    }
    
    private func viewPageHistory() {
        if let pageTitle = pageTitle?.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) {
            let historyUrl = URL(string: "https://oldschool.runescape.wiki/w/Special:History/\(pageTitle)")!
            UIApplication.shared.open(historyUrl)
        }
    }
    
    private func reportIssue() {
        isShowingFeedback = true
    }
}

// Share Sheet implementation
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// Table of Contents Sheet
struct TableOfContentsView: View {
    let sections: [TableOfContentsSection]
    let onSectionSelected: (String) -> Void
    
    var body: some View {
        NavigationStack {
            List(sections) { section in
                Button(action: {
                    onSectionSelected(section.id)
                }) {
                    HStack {
                        Text(section.title)
                            .foregroundStyle(.osrsPrimaryTextColor)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.osrsSecondaryTextColor)
                            .font(.caption)
                    }
                }
                .padding(.leading, CGFloat(section.level * 16))
            }
            .navigationTitle("Contents")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    NavigationStack {
        ArticleView(
            pageTitle: "Dragon",
            pageUrl: URL(string: "https://oldschool.runescape.wiki/w/Dragon")!
        )
        .environmentObject(AppState())
        .environmentObject(osrsThemeManager.preview)
        .environment(\.osrsTheme, osrsLightTheme())
    }
}