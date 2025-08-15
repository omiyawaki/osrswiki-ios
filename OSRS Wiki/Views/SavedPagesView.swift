//
//  SavedPagesView.swift
//  OSRS Wiki
//
//  Created on iOS development session
//

import SwiftUI

struct SavedPagesView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = SavedPagesViewModel()
    @State private var showingSearchView = false
    
    var body: some View {
        NavigationStack(path: $appState.navigationPath) {
            VStack(spacing: 0) {
                if viewModel.savedPages.isEmpty {
                    emptyStateView
                } else {
                    savedPagesListView
                }
            }
            .navigationTitle("Saved Pages")
            .navigationBarTitleDisplayMode(.large)
            .background(appState.currentTheme.backgroundColor)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Search Saved Pages") {
                            showingSearchView = true
                        }
                        
                        Button("Sort by Date") {
                            viewModel.sortBy(.date)
                        }
                        
                        Button("Sort by Title") {
                            viewModel.sortBy(.title)
                        }
                        
                        Divider()
                        
                        Button("Export Reading List") {
                            viewModel.exportReadingList()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showingSearchView) {
                SavedPagesSearchView(viewModel: viewModel)
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
                .foregroundColor(.secondary)
            
            VStack(spacing: 12) {
                Text("No Saved Pages")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text("Save pages while browsing to build your personal reading list")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            Button("Browse Wiki") {
                appState.setSelectedTab(.news)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(appState.currentTheme.primaryColor)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(appState.currentTheme.backgroundColor)
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
        .refreshable {
            await viewModel.refresh()
        }
    }
}

struct SavedPageRowView: View {
    let savedPage: SavedPage
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Page thumbnail or icon
                AsyncImage(url: savedPage.thumbnailUrl) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Image(systemName: "doc.text")
                        .foregroundColor(.secondary)
                }
                .frame(width: 48, height: 48)
                .background(Color(.systemGray6))
                .cornerRadius(8)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(savedPage.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    if let description = savedPage.description {
                        Text(description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                    
                    HStack {
                        Text(savedPage.savedDate, style: .date)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if savedPage.isOfflineAvailable {
                            Spacer()
                            Image(systemName: "arrow.down.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                        }
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
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
                        .foregroundColor(.secondary)
                    
                    TextField("Search saved pages", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                }
                .padding()
                .background(Color(.systemGray6))
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

#Preview {
    SavedPagesView()
        .environmentObject(AppState())
}