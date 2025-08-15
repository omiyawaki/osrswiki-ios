//
//  HistoryView.swift
//  OSRS Wiki
//
//  Created on iOS feature parity session
//

import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = HistoryViewModel()
    @State private var searchText = ""
    @State private var showingClearConfirmation = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                searchBar
                
                if viewModel.historyEntries.isEmpty {
                    emptyStateView
                } else {
                    historyList
                }
            }
            .navigationTitle("Reading History")
            .navigationBarTitleDisplayMode(.large)
            .background(appState.currentTheme.backgroundColor)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Clear All History", role: .destructive) {
                            showingClearConfirmation = true
                        }
                        Button("Export History") {
                            viewModel.exportHistory()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search history...")
            .onAppear {
                viewModel.loadHistory()
            }
            .alert("Clear History", isPresented: $showingClearConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Clear All", role: .destructive) {
                    viewModel.clearAllHistory()
                }
            } message: {
                Text("This will permanently delete all your reading history. This action cannot be undone.")
            }
        }
    }
    
    private var searchBar: some View {
        HStack {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search pages...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .cornerRadius(10)
            
            Button(action: {
                // TODO: Implement voice search
            }) {
                Image(systemName: "mic.fill")
                    .foregroundColor(.blue)
                    .padding(.horizontal, 8)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(appState.currentTheme.backgroundColor)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "clock.fill")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No History Yet")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text("Pages you visit will appear here for easy access later.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button(action: {
                // Navigate to search or main page
                appState.setSelectedTab(.search)
            }) {
                Text("Start Browsing")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .cornerRadius(8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(appState.currentTheme.backgroundColor)
    }
    
    private var historyList: some View {
        List {
            ForEach(filteredHistoryEntries) { entry in
                HistoryEntryRowView(entry: entry) {
                    viewModel.removeHistoryEntry(entry)
                }
                .listRowBackground(appState.currentTheme.backgroundColor)
            }
            .onDelete(perform: deleteEntries)
        }
        .listStyle(PlainListStyle())
        .refreshable {
            viewModel.loadHistory()
        }
    }
    
    private var filteredHistoryEntries: [ReadingHistoryEntry] {
        if searchText.isEmpty {
            return viewModel.historyEntries
        } else {
            return viewModel.historyEntries.filter { entry in
                entry.displayText.localizedCaseInsensitiveContains(searchText) ||
                (entry.snippet?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
    }
    
    private func deleteEntries(at offsets: IndexSet) {
        let entriesToDelete = offsets.map { filteredHistoryEntries[$0] }
        for entry in entriesToDelete {
            viewModel.removeHistoryEntry(entry)
        }
    }
}

struct HistoryEntryRowView: View {
    let entry: ReadingHistoryEntry
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail or icon
            AsyncImage(url: entry.thumbnailUrl) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Image(systemName: "doc.text.fill")
                    .foregroundColor(.secondary)
                    .font(.title2)
            }
            .frame(width: 44, height: 44)
            .background(Color(.systemGray6))
            .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.displayText)
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .foregroundColor(.primary)
                
                if let snippet = entry.snippet, !snippet.isEmpty {
                    Text(snippet)
                        .font(.caption)
                        .lineLimit(2)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text(entry.sourceDescription)
                        .font(.caption2)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(4)
                    
                    Spacer()
                    
                    Text(entry.timestamp, style: .relative)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button("Delete", role: .destructive) {
                onDelete()
            }
        }
    }
}

// MARK: - ReadingHistoryEntry Model
struct ReadingHistoryEntry: Identifiable, Hashable {
    let id = UUID()
    let wikiUrl: String
    let displayText: String
    let pageId: Int?
    let apiPath: String
    let timestamp: Date
    let source: Int
    let snippet: String?
    let thumbnailUrl: URL?
    
    var sourceDescription: String {
        switch source {
        case 1: return "Search"
        case 2: return "Link"
        case 3: return "External"
        case 4: return "History"
        case 5: return "Saved"
        case 6: return "Main"
        case 7: return "Random"
        case 8: return "News"
        default: return "Unknown"
        }
    }
}

// MARK: - HistoryViewModel
class HistoryViewModel: ObservableObject {
    @Published var historyEntries: [ReadingHistoryEntry] = []
    @Published var isLoading = false
    
    func loadHistory() {
        isLoading = true
        
        // TODO: Load from persistent storage (Core Data, SQLite, etc.)
        // For now, populate with sample data
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.historyEntries = self.sampleHistoryEntries()
            self.isLoading = false
        }
    }
    
    func removeHistoryEntry(_ entry: ReadingHistoryEntry) {
        historyEntries.removeAll { $0.id == entry.id }
        // TODO: Remove from persistent storage
    }
    
    func clearAllHistory() {
        historyEntries.removeAll()
        // TODO: Clear from persistent storage
    }
    
    func exportHistory() {
        // TODO: Implement history export functionality
    }
    
    private func sampleHistoryEntries() -> [ReadingHistoryEntry] {
        return [
            ReadingHistoryEntry(
                wikiUrl: "https://oldschool.runescape.wiki/w/Dragon_scimitar",
                displayText: "Dragon scimitar",
                pageId: 1234,
                apiPath: "/Dragon_scimitar",
                timestamp: Date().addingTimeInterval(-3600), // 1 hour ago
                source: 1,
                snippet: "The dragon scimitar is a scimitar requiring level 60 Attack to wield. It can be bought from Daga on Ape Atoll...",
                thumbnailUrl: nil
            ),
            ReadingHistoryEntry(
                wikiUrl: "https://oldschool.runescape.wiki/w/Barrows",
                displayText: "Barrows",
                pageId: 5678,
                apiPath: "/Barrows",
                timestamp: Date().addingTimeInterval(-7200), // 2 hours ago
                source: 8,
                snippet: "The Barrows is an area-based combat minigame. It involves defeating the six Barrows brothers...",
                thumbnailUrl: nil
            ),
            ReadingHistoryEntry(
                wikiUrl: "https://oldschool.runescape.wiki/w/Monkey_Madness_I",
                displayText: "Monkey Madness I",
                pageId: 9012,
                apiPath: "/Monkey_Madness_I",
                timestamp: Date().addingTimeInterval(-86400), // 1 day ago
                source: 2,
                snippet: "Monkey Madness I is a quest in the Gnome quest series and the sequel to The Grand Tree...",
                thumbnailUrl: nil
            )
        ]
    }
}

#Preview {
    HistoryView()
        .environmentObject(AppState())
}