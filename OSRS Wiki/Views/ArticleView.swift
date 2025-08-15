//
//  ArticleView.swift
//  OSRS Wiki
//
//  Created on iOS webviewer implementation session
//

import SwiftUI
import WebKit

struct ArticleView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel: ArticleViewModel
    @State private var isShowingShareSheet = false
    @State private var isShowingTableOfContents = false
    
    let pageTitle: String
    let pageUrl: URL
    
    init(pageTitle: String, pageUrl: URL) {
        self.pageTitle = pageTitle
        self.pageUrl = pageUrl
        self._viewModel = StateObject(wrappedValue: ArticleViewModel(pageUrl: pageUrl))
    }
    
    var body: some View {
        ZStack {
            // Background
            appState.currentTheme.backgroundColor
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Progress bar
                if viewModel.isLoading {
                    ProgressView(value: viewModel.loadingProgress, total: 1.0)
                        .progressViewStyle(LinearProgressViewStyle())
                        .transition(.opacity)
                }
                
                // WebView content
                ArticleWebView(viewModel: viewModel)
                    .environmentObject(appState)
            }
        }
        .navigationTitle(pageTitle)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(false)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    // Save/Bookmark button
                    Button(action: {
                        viewModel.toggleBookmark()
                    }) {
                        Image(systemName: viewModel.isBookmarked ? "bookmark.fill" : "bookmark")
                            .foregroundColor(viewModel.isBookmarked ? .yellow : .primary)
                    }
                    
                    // Table of contents button
                    Button(action: {
                        isShowingTableOfContents = true
                    }) {
                        Image(systemName: "list.bullet")
                    }
                    .disabled(!viewModel.hasTableOfContents)
                    
                    // Share button
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
            viewModel.loadArticle()
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
    .environmentObject(AppState())
}