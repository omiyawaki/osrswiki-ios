//
//  NewsRepository.swift
//  OSRS Wiki
//
//  Created on iOS development session
//

import Foundation

class NewsRepository {
    private let baseURL = "https://oldschool.runescape.wiki/api.php"
    
    func fetchLatestNews() async throws -> [NewsItem] {
        // Simulate API call for now
        // In a real implementation, this would call the MediaWiki API
        
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
        
        // Return mock data that matches Android app structure
        return [
            NewsItem(
                id: "1",
                title: "Forestry: The Way of the Forester",
                summary: "Train Forestry, a new way to train Woodcutting, featuring events, special logs, and unique rewards!",
                content: nil,
                imageUrl: URL(string: "https://secure.runescape.com/m=news/gfx/2023/forestry.jpg"),
                publishedDate: Date().addingTimeInterval(-86400), // 1 day ago
                category: .update,
                url: URL(string: "https://oldschool.runescape.wiki/w/Forestry")
            ),
            NewsItem(
                id: "2", 
                title: "Desert Treasure II - The Fallen Empire",
                summary: "The epic sequel to one of OSRS's most beloved quests is here! Face new challenges and unlock powerful rewards.",
                content: nil,
                imageUrl: URL(string: "https://secure.runescape.com/m=news/gfx/2023/dt2.jpg"),
                publishedDate: Date().addingTimeInterval(-172800), // 2 days ago
                category: .update,
                url: URL(string: "https://oldschool.runescape.wiki/w/Desert_Treasure_II")
            ),
            NewsItem(
                id: "3",
                title: "Combat Achievements",
                summary: "Test your PvM skills with hundreds of combat challenges and unlock prestigious rewards!",
                content: nil,
                imageUrl: nil,
                publishedDate: Date().addingTimeInterval(-259200), // 3 days ago
                category: .announcement,
                url: URL(string: "https://oldschool.runescape.wiki/w/Combat_Achievements")
            )
        ]
    }
}