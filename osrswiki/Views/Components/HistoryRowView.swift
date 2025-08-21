//
//  HistoryRowView.swift
//  OSRS Wiki
//
//  Created on iOS theming fixes session
//

import SwiftUI

struct HistoryRowView: View {
    @Environment(\.osrsTheme) var osrsTheme
    let historyItem: ThemedHistoryItem
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // History icon
                Image(systemName: "clock.fill")
                    .font(.title3)
                    .foregroundStyle(.osrsSecondaryTextColor)
                    .frame(width: 40, height: 40)
                    .background(.osrsSearchBoxBackgroundColor)
                    .cornerRadius(8)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(historyItem.pageTitle)
                        .font(.body)
                        .fontWeight(.medium)
                        .lineLimit(2)
                        .foregroundStyle(.osrsPrimaryTextColor)
                        .multilineTextAlignment(.leading)
                    
                    if let snippet = historyItem.snippet, !snippet.isEmpty {
                        Text(snippet)
                            .font(.caption)
                            .lineLimit(2)
                            .foregroundStyle(.osrsSecondaryTextColor)
                            .multilineTextAlignment(.leading)
                    }
                    
                    HStack {
                        Text(historyItem.timestamp, style: .relative)
                            .font(.caption2)
                            .foregroundStyle(.osrsSecondaryTextColor)
                        
                        Spacer()
                        
                        Text(historyItem.sourceDescription)
                            .font(.caption2)
                            .foregroundStyle(.osrsPrimary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.osrsPrimaryContainer)
                            .cornerRadius(4)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.osrsPlaceholderColor)
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .listRowBackground(osrsTheme.surface)
        .listRowSeparator(.visible, edges: .bottom)
        .listRowSeparatorTint(osrsTheme.divider)
    }
}

// MARK: - ThemedHistoryItem Model
struct ThemedHistoryItem: Identifiable, Hashable {
    let id = UUID()
    let pageTitle: String
    let pageUrl: String
    let snippet: String?
    let timestamp: Date
    let source: Int
    
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
    
    init(pageTitle: String, pageUrl: String, snippet: String? = nil, timestamp: Date = Date(), source: Int = 1) {
        self.pageTitle = pageTitle
        self.pageUrl = pageUrl
        self.snippet = snippet
        self.timestamp = timestamp
        self.source = source
    }
}

#Preview {
    List {
        HistoryRowView(
            historyItem: ThemedHistoryItem(
                pageTitle: "Dragon scimitar",
                pageUrl: "https://oldschool.runescape.wiki/w/Dragon_scimitar",
                snippet: "The dragon scimitar is a scimitar requiring level 60 Attack to wield.",
                timestamp: Date().addingTimeInterval(-3600),
                source: 1
            ),
            onTap: { }
        )
        
        HistoryRowView(
            historyItem: ThemedHistoryItem(
                pageTitle: "Barrows minigame guide",
                pageUrl: "https://oldschool.runescape.wiki/w/Barrows",
                snippet: "The Barrows is an area-based combat minigame involving the six Barrows brothers.",
                timestamp: Date().addingTimeInterval(-7200),
                source: 8
            ),
            onTap: { }
        )
    }
    .listStyle(PlainListStyle())
    .environment(\.osrsTheme, osrsLightTheme())
}