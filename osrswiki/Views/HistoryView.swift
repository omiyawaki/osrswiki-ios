//
//  HistoryView.swift
//  OSRS Wiki
//
//  Created on iOS feature parity session
//

import SwiftUI

struct HistoryView: View {
    @Environment(\.osrsTheme) var osrsTheme
    @StateObject private var viewModel = HistoryViewModel()
    @State private var showingClearConfirmation = false
    @State private var showingSearchModal = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Custom header matching NewsView layout
                HistoryHeaderView(
                    onClearHistory: { showingClearConfirmation = true },
                    onExportHistory: { viewModel.exportHistory() }
                )
                
                // Search bar at top (matches Android and home page)
                SearchBarView(placeholder: "Search OSRS Wiki") {
                    // Show DedicatedSearchView modal (same as home page)
                    showingSearchModal = true
                }
                .padding(.horizontal)
                .padding(.top, 8)
                
                if viewModel.historyEntries.isEmpty {
                    emptyStateView
                } else {
                    historyList
                }
            }
            .navigationTitle("")
            .navigationBarHidden(true)
            .background(.osrsBackground)
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
            .fullScreenCover(isPresented: $showingSearchModal) {
                // Dedicated search modal (matches home page behavior)
                DedicatedSearchView(isPresented: $showingSearchModal)
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "clock.fill")
                .font(.system(size: 60))
                .foregroundStyle(.osrsOnSurfaceVariant)
            
            Text("No History Yet")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(.osrsOnSurface)
            
            Text("Pages you visit will appear here for easy access later.")
                .font(.body)
                .foregroundStyle(.osrsTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button(action: {
                // Navigate to search or main page
                // Navigate to search - TODO: implement navigation
            }) {
                Text("Start Browsing")
                    .font(.headline)
                    .foregroundStyle(.osrsOnPrimary)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(.osrsPrimary)
                    .cornerRadius(8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.osrsBackground)
    }
    
    private var historyList: some View {
        List {
            ForEach(viewModel.historyEntries) { entry in
                HistoryEntryRowView(entry: entry) {
                    viewModel.removeHistoryEntry(entry)
                }
                .listRowBackground(osrsTheme.surface)
            }
            .onDelete(perform: deleteEntries)
        }
        .listStyle(PlainListStyle())
        .refreshable {
            viewModel.loadHistory()
        }
    }
    
    
    private func deleteEntries(at offsets: IndexSet) {
        let entriesToDelete = offsets.map { viewModel.historyEntries[$0] }
        for entry in entriesToDelete {
            viewModel.removeHistoryEntry(entry)
        }
    }
}

struct HistoryHeaderView: View {
    let onClearHistory: () -> Void
    let onExportHistory: () -> Void
    
    var body: some View {
        HStack {
            // Left-aligned "History" title matching NewsView HeaderView
            Text("History")
                .font(.osrsDisplay)
                .foregroundStyle(.osrsOnSurface)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Right-aligned menu button (matches the ellipsis menu)
            Menu {
                Button("Clear All History", role: .destructive) {
                    onClearHistory()
                }
                Button("Export History") {
                    onExportHistory()
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 24))
                    .foregroundStyle(.osrsOnSurfaceVariant)
                    .frame(width: 48, height: 48)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.osrsBackground)
    }
}

struct HistoryEntryRowView: View {
    @Environment(\.osrsTheme) var osrsTheme
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
                    .foregroundStyle(.osrsOnSurfaceVariant)
                    .font(.title2)
            }
            .frame(width: 44, height: 44)
            .background(.osrsSurfaceVariant)
            .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.displayText)
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .foregroundStyle(.osrsOnSurface)
                
                if let snippet = entry.snippet, !snippet.isEmpty {
                    Text(snippet)
                        .font(.caption)
                        .lineLimit(2)
                        .foregroundStyle(.osrsTextSecondary)
                }
                
                HStack {
                    Text(entry.sourceDescription)
                        .font(.caption2)
                        .foregroundStyle(.osrsPrimary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.osrsPrimaryContainer)
                        .cornerRadius(4)
                    
                    Spacer()
                    
                    Text(entry.timestamp, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.osrsTextSecondary)
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
        .environment(\.osrsTheme, osrsLightTheme())
}