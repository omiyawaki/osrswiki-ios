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
    @StateObject private var viewModel: ArticleViewModel
    @State private var isShowingShareSheet = false
    @State private var isShowingTableOfContents = false
    
    let pageTitle: String?
    let pageUrl: URL
    
    init(pageTitle: String?, pageUrl: URL) {
        self.pageTitle = pageTitle
        self.pageUrl = pageUrl
        self._viewModel = StateObject(wrappedValue: ArticleViewModel(pageUrl: pageUrl, pageTitle: pageTitle, pageId: nil))
        print("🏗️ ArticleView: Created with title='\(pageTitle ?? "nil")' url=\(pageUrl)")
    }
    
    var body: some View {
        VStack(spacing: 0) {
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
        .navigationTitle(pageTitle ?? "Article")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                // Keep only share button in top toolbar to maintain some utility
                Button(action: {
                    isShowingShareSheet = true
                }) {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
            .sheet(isPresented: $isShowingShareSheet) {
                ShareSheet(items: [pageUrl])
            }
            .sheet(isPresented: $isShowingTableOfContents) {
                TableOfContentsView(
                    sections: viewModel.tableOfContents,
                    onSectionSelected: { sectionId in
                        viewModel.scrollToSection(sectionId)
                        isShowingTableOfContents = false
                    }
                )
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
        .onAppear {
            print("📱 ArticleView: onAppear called - loading article")
            viewModel.loadArticle(theme: osrsTheme)
        }
        .onChange(of: osrsTheme as? osrsLightTheme != nil) { _, _ in
            // Reload with new theme when theme changes
            viewModel.loadArticle(theme: osrsTheme)
        }
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
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
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
    ArticleView(
        pageTitle: "Dragon",
        pageUrl: URL(string: "https://oldschool.runescape.wiki/w/Dragon")!
    )
    .environment(\.osrsTheme, osrsLightTheme())
}