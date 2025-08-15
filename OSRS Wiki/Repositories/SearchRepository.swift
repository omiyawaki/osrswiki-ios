//
//  SearchRepository.swift
//  OSRS Wiki
//
//  Created on iOS development session
//

import Foundation

class SearchRepository {
    private let baseURL = "https://oldschool.runescape.wiki/api.php"
    
    func search(query: String) async throws -> [SearchResult] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }
        
        // Build MediaWiki API search URL
        var components = URLComponents(string: baseURL)!
        components.queryItems = [
            URLQueryItem(name: "action", value: "query"),
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "list", value: "search"),
            URLQueryItem(name: "srsearch", value: query),
            URLQueryItem(name: "srlimit", value: "10"),
            URLQueryItem(name: "srprop", value: "snippet|titlesnippet|size|timestamp"),
            URLQueryItem(name: "srnamespace", value: "0") // Main namespace only
        ]
        
        guard let url = components.url else {
            throw URLError(.badURL)
        }
        
        // Make API request
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        // Parse JSON response
        let searchResponse = try JSONDecoder().decode(WikiSearchResponse.self, from: data)
        
        // Convert to SearchResult objects
        return searchResponse.query.search.map { result in
            let cleanTitle = result.title.replacingOccurrences(of: " ", with: "_")
            let wikiURL = URL(string: "https://oldschool.runescape.wiki/w/\(cleanTitle)")!
            
            return SearchResult(
                id: String(result.pageid),
                title: result.title,
                description: result.snippet?.htmlStripped(),
                url: wikiURL,
                thumbnailUrl: nil, // Could be enhanced to fetch thumbnails
                namespace: "Main",
                score: nil
            )
        }
    }
}

// MARK: - MediaWiki API Response Models
struct WikiSearchResponse: Codable {
    let query: WikiQuery
}

struct WikiQuery: Codable {
    let search: [WikiSearchResult]
}

struct WikiSearchResult: Codable {
    let pageid: Int
    let title: String
    let snippet: String?
    let size: Int?
    let timestamp: String?
}

// MARK: - Helper Extensions
extension String {
    func htmlStripped() -> String {
        // Remove HTML tags from snippet
        return self.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression, range: nil)
                  .replacingOccurrences(of: "&quot;", with: "\"")
                  .replacingOccurrences(of: "&amp;", with: "&")
                  .replacingOccurrences(of: "&lt;", with: "<")
                  .replacingOccurrences(of: "&gt;", with: ">")
    }
}