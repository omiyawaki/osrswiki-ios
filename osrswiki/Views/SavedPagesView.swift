//
//  SavedPagesView.swift
//  OSRS Wiki
//
//  Created on iOS development session
//

import SwiftUI

struct SavedPagesView: View {
    @Environment(\.osrsTheme) var osrsTheme
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = SavedPagesViewModel()
    @State private var showingSearchView = false
    
    var body: some View {
        NavigationStack(path: $appState.savedNavigationPath) {
            VStack(spacing: 0) {
                // Custom header matching Home and History layout
                SavedPagesHeaderView(
                    onSearchSavedPages: { showingSearchView = true },
                    onSortByDate: { viewModel.sortBy(.date) },
                    onSortByTitle: { viewModel.sortBy(.title) },
                    onClearAllSavedPages: { viewModel.clearAllSavedPages() },
                    onExportReadingList: { viewModel.exportReadingList() }
                )
                
                if viewModel.savedPages.isEmpty {
                    emptyStateView
                } else {
                    savedPagesListView
                }
            }
            .navigationTitle("")
            .navigationBarHidden(true)
            .background(.osrsBackground)
            .sheet(isPresented: $showingSearchView) {
                SavedPagesSearchView(viewModel: viewModel)
            }
            .navigationDestination(for: NavigationDestination.self) { destination in
                switch destination {
                case .search:
                    DedicatedSearchView()
                        .environmentObject(appState)
                        .environment(\.osrsTheme, osrsTheme)
                case .article(let articleDestination):
                    ArticleView(pageTitle: articleDestination.title, pageUrl: articleDestination.url)
                        .environmentObject(appState)
                        .environment(\.osrsTheme, osrsTheme)
                }
            }
        }
        .task {
            await viewModel.loadSavedPages()
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "bookmark")
                .font(.system(size: 64))
                .foregroundStyle(.osrsPlaceholderColor)
            
            VStack(spacing: 12) {
                Text("No Saved Pages")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.osrsPrimaryTextColor)
                
                Text("Save pages while browsing to build your personal reading list")
                    .font(.body)
                    .foregroundStyle(.osrsSecondaryTextColor)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            Button("Browse Wiki") {
                // TODO: Navigate to news tab - implement navigation
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(.osrsPrimary)
            .foregroundStyle(.osrsOnPrimary)
            .cornerRadius(8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.osrsBackground)
    }
    
    private var savedPagesListView: some View {
        List {
            ForEach(viewModel.savedPages) { savedPage in
                SavedPageRowView(savedPage: savedPage) {
                    viewModel.navigateToPage(savedPage)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button("Delete", role: .destructive) {
                        viewModel.removeSavedPage(savedPage)
                    }
                }
                .swipeActions(edge: .leading) {
                    Button("Share") {
                        viewModel.sharePage(savedPage)
                    }
                    .tint(.blue)
                }
            }
            .onMove { from, to in
                viewModel.moveSavedPages(from: from, to: to)
            }
        }
        .listStyle(PlainListStyle())
        .scrollContentBackground(.hidden)
        .background(.osrsBackground)
        .refreshable {
            await viewModel.refresh()
        }
    }
}

struct SavedPageRowView: View {
    @Environment(\.osrsTheme) var osrsTheme
    let savedPage: SavedPage
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Main content section (title and description) - matches search results
                VStack(alignment: .leading, spacing: 4) {
                    Text(osrsStringUtils.extractMainTitle(savedPage.title))
                        .font(.osrsListTitle)  // Use same font as search results
                        .lineLimit(2)
                        .foregroundStyle(.osrsPrimaryTextColor)
                        .multilineTextAlignment(.leading)
                    
                    if let description = savedPage.description {
                        Text(description)
                            .font(.subheadline)
                            .lineLimit(2)
                            .foregroundStyle(.osrsPrimaryTextColor) // Use primary color to match title
                            .multilineTextAlignment(.leading)
                    }
                    
                    HStack {
                        Text(savedPage.savedDate, style: .date)
                            .font(.caption)
                            .foregroundStyle(.osrsSecondaryTextColor)
                        
                        if savedPage.isOfflineAvailable {
                            Spacer()
                            Image(systemName: "arrow.down.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                        }
                    }
                }
                
                Spacer()
                
                // Thumbnail positioned on the right (matching search results layout)
                AsyncImage(url: savedPage.thumbnailUrl) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .clipped()
                } placeholder: {
                    Image(systemName: "doc.text.fill")
                        .foregroundStyle(.osrsPlaceholderColor)
                        .font(.title2)
                }
                .frame(width: 60, height: 60)  // Match search results size
                .background(.osrsSearchBoxBackgroundColor)  // Match search results background
                .cornerRadius(8)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .listRowBackground(osrsTheme.surface)  // Proper theme background
        .listRowSeparator(.visible, edges: .bottom)
        .listRowSeparatorTint(osrsTheme.divider)
    }
}

struct SavedPagesSearchView: View {
    @ObservedObject var viewModel: SavedPagesViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    
    var body: some View {
        NavigationStack {
            VStack {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.osrsPlaceholderColor)
                    
                    TextField("Search saved pages", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                }
                .padding()
                .background(.osrsSearchBoxBackgroundColor)
                .cornerRadius(10)
                .padding()
                
                // Filtered results
                List(viewModel.filteredSavedPages(searchText: searchText)) { savedPage in
                    SavedPageRowView(savedPage: savedPage) {
                        viewModel.navigateToPage(savedPage)
                        dismiss()
                    }
                }
                .listStyle(PlainListStyle())
            }
            .navigationTitle("Search Saved Pages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct SavedPagesHeaderView: View {
    let onSearchSavedPages: () -> Void
    let onSortByDate: () -> Void
    let onSortByTitle: () -> Void
    let onClearAllSavedPages: () -> Void
    let onExportReadingList: () -> Void
    
    var body: some View {
        HStack {
            // Left-aligned "Saved Pages" title matching Home and History
            Text("Saved Pages")
                .font(.osrsDisplay)
                .foregroundStyle(.osrsPrimaryTextColor)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Right-aligned menu button (matches History and Home ellipsis menu)
            Menu {
                Button("Search Saved Pages") {
                    onSearchSavedPages()
                }
                
                Button("Sort by Date") {
                    onSortByDate()
                }
                
                Button("Sort by Title") {
                    onSortByTitle()
                }
                
                Divider()
                
                Button("Clear All Saved Pages", role: .destructive) {
                    onClearAllSavedPages()
                }
                
                Button("Export Reading List") {
                    onExportReadingList()
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 24))
                    .foregroundStyle(.osrsPlaceholderColor)
                    .frame(width: 48, height: 48)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.osrsBackground)
    }
}

#Preview {
    SavedPagesView()
        .environment(\.osrsTheme, osrsLightTheme())
}