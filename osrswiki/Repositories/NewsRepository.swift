//
//  NewsRepository.swift
//  OSRS Wiki
//
//  Created on iOS development session
//

import Foundation

class NewsRepository {
    private let baseURL = "https://oldschool.runescape.wiki"
    private let wikiURL = "https://oldschool.runescape.wiki/"
    
    func fetchWikiFeed() async throws -> WikiFeed {
        guard let url = URL(string: wikiURL) else {
            throw NewsError.invalidURL
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let html = String(data: data, encoding: .utf8) else {
            throw NewsError.invalidData
        }
        
        return WikiFeed(
            recentUpdates: parseRecentUpdates(html),
            announcements: parseAnnouncements(html),
            onThisDay: parseOnThisDay(html),
            popularPages: parsePopularPages(html)
        )
    }
    
    // For backwards compatibility with existing NewsViewModel
    func fetchLatestNews() async throws -> [NewsItem] {
        let wikiFeed = try await fetchWikiFeed()
        return transformFeedToNewsItems(wikiFeed)
    }
    
    private func parseRecentUpdates(_ html: String) -> [UpdateItem] {
        var updates: [UpdateItem] = []
        
        // Find the start of mainpage-recent-updates section
        guard let startRange = html.range(of: #"<div[^>]*class="[^"]*mainpage-recent-updates"#, options: .regularExpression) else {
            print("📰 mainpage-recent-updates section not found")
            return updates
        }
        
        // Find the end marker (next major section)
        let searchAfterStart = html[startRange.upperBound...]
        let endPattern = #"<div[^>]*class="[^"]*mainpage-contents"#
        let endRange = searchAfterStart.range(of: endPattern, options: .regularExpression)
        
        // Extract the content section
        let containerContent: String
        if let endRange = endRange {
            containerContent = String(html[startRange.lowerBound..<endRange.lowerBound])
        } else {
            // Fallback: take everything after start
            containerContent = String(html[startRange.lowerBound...])
        }
        
        print("📰 Extracted container content, length: \(containerContent.count)")
        
        // Find all tile-halves within this content
        let tilePattern = #"<div[^>]*class="[^"]*tile-halves[^"]*"[^>]*>(.*?)</div>\s*</div>"#
        
        do {
            let tileRegex = try NSRegularExpression(pattern: tilePattern, options: [.caseInsensitive, .dotMatchesLineSeparators])
            let tileMatches = tileRegex.matches(in: containerContent, options: [], range: NSRange(containerContent.startIndex..., in: containerContent))
            
            print("📰 Found \(tileMatches.count) tile-halves in recent updates")
            
            for (index, match) in tileMatches.prefix(5).enumerated() {
                guard let tileRange = Range(match.range(at: 1), in: containerContent) else { continue }
                let tileContent = String(containerContent[tileRange])
                
                print("📰 Processing tile \(index + 1):")
                print("   First 200 chars: \(String(tileContent.prefix(200)))")
                
                // Extract title from h2 within tile-bottom a tag
                let titlePattern = #"<div[^>]*class="[^"]*tile-bottom[^"]*"[^>]*>.*?<a[^>]*>.*?<h2[^>]*>(.*?)</h2>"#
                let title = extractFirst(pattern: titlePattern, from: tileContent) ?? "Recent Update"
                
                // Extract snippet from last p tag within tile-bottom a tag (matching Android approach)
                let pTagPattern = #"<p[^>]*>(.*?)</p>"#
                let allPTagsInTile = extractAll(pattern: pTagPattern, from: tileContent)
                let snippet = allPTagsInTile.last.map { cleanHTML($0) } ?? ""
                
                // Extract href from tile-bottom a tag
                let hrefPattern = #"<div[^>]*class="[^"]*tile-bottom[^"]*"[^>]*>.*?<a[^>]*href="([^"]+)""#
                let href = extractFirst(pattern: hrefPattern, from: tileContent) ?? ""
                let articleUrl = href.starts(with: "/") ? "\(baseURL)\(href)" : href
                
                // Extract image from tile-top
                let imgSrcPattern = #"<div[^>]*class="[^"]*tile-top[^"]*"[^>]*>.*?<img[^>]*src="([^"]+)""#
                let imgSrc = extractFirst(pattern: imgSrcPattern, from: tileContent) ?? ""
                let imageUrl = imgSrc.starts(with: "/") ? "\(baseURL)\(imgSrc)" : imgSrc
                
                let cleanTitle = cleanHTML(title)
                let cleanSnippet = snippet // Already cleaned above
                
                print("   Extracted title: '\(cleanTitle)'")
                print("   Extracted snippet: '\(cleanSnippet)'")
                print("   Article URL: '\(articleUrl)'")
                print("   Image URL: '\(imageUrl)'")
                
                if !cleanTitle.isEmpty && cleanTitle != "Recent Update" {
                    updates.append(UpdateItem(
                        title: cleanTitle,
                        snippet: cleanSnippet,
                        imageUrl: imageUrl,
                        articleUrl: articleUrl
                    ))
                }
            }
        } catch {
            print("Error parsing recent updates: \(error)")
        }
        
        print("📰 Total updates parsed: \(updates.count)")
        return updates
    }
    
    private func parseAnnouncements(_ html: String) -> [AnnouncementItem] {
        var announcements: [AnnouncementItem] = []
        
        // Look for wikinews section
        let wikinewsPattern = #"<div[^>]*class="[^"]*mainpage-wikinews[^"]*"[^>]*>(.*?)</div>"#
        let dtPattern = #"<dt[^>]*>(.*?)</dt>"#
        let ddPattern = #"<dd[^>]*>(.*?)</dd>"#
        
        do {
            let wikinewsRegex = try NSRegularExpression(pattern: wikinewsPattern, options: [.caseInsensitive, .dotMatchesLineSeparators])
            let matches = wikinewsRegex.matches(in: html, options: [], range: NSRange(html.startIndex..., in: html))
            
            for match in matches {
                guard let wikinewsRange = Range(match.range(at: 1), in: html) else { continue }
                let wikinewsContent = String(html[wikinewsRange])
                
                let dates = extractAll(pattern: dtPattern, from: wikinewsContent)
                let contents = extractAll(pattern: ddPattern, from: wikinewsContent)
                
                for (date, content) in zip(dates, contents) {
                    announcements.append(AnnouncementItem(
                        date: cleanHTML(date),
                        content: content
                    ))
                }
            }
        } catch {
            print("Error parsing announcements: \(error)")
        }
        
        return announcements
    }
    
    private func parseOnThisDay(_ html: String) -> OnThisDayItem? {
        let onThisDayPattern = #"<div[^>]*class="[^"]*mainpage-onthisday[^"]*"[^>]*>(.*?)</div>"#
        let h2Pattern = #"<h2[^>]*>(.*?)</h2>"#
        let liPattern = #"<li[^>]*>(.*?)</li>"#
        
        do {
            let onThisDayRegex = try NSRegularExpression(pattern: onThisDayPattern, options: [.caseInsensitive, .dotMatchesLineSeparators])
            let matches = onThisDayRegex.matches(in: html, options: [], range: NSRange(html.startIndex..., in: html))
            
            for match in matches {
                guard let onThisDayRange = Range(match.range(at: 1), in: html) else { continue }
                let onThisDayContent = String(html[onThisDayRange])
                
                let title = extractFirst(pattern: h2Pattern, from: onThisDayContent) ?? "On this day..."
                let events = extractAll(pattern: liPattern, from: onThisDayContent)
                
                if !events.isEmpty {
                    return OnThisDayItem(title: cleanHTML(title), events: events)
                }
            }
        } catch {
            print("Error parsing on this day: \(error)")
        }
        
        return nil
    }
    
    private func parsePopularPages(_ html: String) -> [PopularPageItem] {
        var popularPages: [PopularPageItem] = []
        
        let popularPattern = #"<div[^>]*class="[^"]*mainpage-popular[^"]*"[^>]*>(.*?)</div>"#
        let linkPattern = #"<a[^>]*href="([^"]+)"[^>]*>(.*?)</a>"#
        
        do {
            let popularRegex = try NSRegularExpression(pattern: popularPattern, options: [.caseInsensitive, .dotMatchesLineSeparators])
            let matches = popularRegex.matches(in: html, options: [], range: NSRange(html.startIndex..., in: html))
            
            for match in matches {
                guard let popularRange = Range(match.range(at: 1), in: html) else { continue }
                let popularContent = String(html[popularRange])
                
                let linkRegex = try NSRegularExpression(pattern: linkPattern, options: [.caseInsensitive])
                let linkMatches = linkRegex.matches(in: popularContent, options: [], range: NSRange(popularContent.startIndex..., in: popularContent))
                
                for linkMatch in linkMatches {
                    guard let hrefRange = Range(linkMatch.range(at: 1), in: popularContent),
                          let titleRange = Range(linkMatch.range(at: 2), in: popularContent) else { continue }
                    
                    let href = String(popularContent[hrefRange])
                    let title = String(popularContent[titleRange])
                    let pageUrl = href.starts(with: "/") ? "\(baseURL)\(href)" : href
                    
                    popularPages.append(PopularPageItem(
                        title: cleanHTML(title),
                        pageUrl: pageUrl
                    ))
                }
            }
        } catch {
            print("Error parsing popular pages: \(error)")
        }
        
        return popularPages
    }
    
    func transformFeedToNewsItems(_ feed: WikiFeed) -> [NewsItem] {
        var items: [NewsItem] = []
        
        // Convert recent updates to news items
        for (index, update) in feed.recentUpdates.enumerated() {
            items.append(NewsItem(
                id: "update_\(index)",
                title: update.title,
                summary: update.snippet,
                content: nil,
                imageUrl: URL(string: update.imageUrl),
                publishedDate: Date(), // We don't have publish dates from scraping
                category: .update,
                url: URL(string: update.articleUrl)
            ))
        }
        
        // Convert announcements to news items
        for (index, announcement) in feed.announcements.enumerated() {
            items.append(NewsItem(
                id: "announcement_\(index)",
                title: "Wiki News: \(announcement.date)",
                summary: announcement.content.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression),
                content: nil,
                imageUrl: nil,
                publishedDate: Date(),
                category: .announcement,
                url: nil
            ))
        }
        
        return items
    }
    
    // MARK: - Helper Methods
    
    private func extractFirst(pattern: String, from text: String) -> String? {
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
            let matches = regex.matches(in: text, options: [], range: NSRange(text.startIndex..., in: text))
            
            if let match = matches.first,
               let range = Range(match.range(at: 1), in: text) {
                return String(text[range])
            }
        } catch {
            print("Error extracting with pattern \(pattern): \(error)")
        }
        
        return nil
    }
    
    private func extractLast(pattern: String, from text: String) -> String? {
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
            let matches = regex.matches(in: text, options: [], range: NSRange(text.startIndex..., in: text))
            
            if let match = matches.last,
               let range = Range(match.range(at: 1), in: text) {
                return String(text[range])
            }
        } catch {
            print("Error extracting with pattern \(pattern): \(error)")
        }
        
        return nil
    }
    
    private func extractAll(pattern: String, from text: String) -> [String] {
        var results: [String] = []
        
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
            let matches = regex.matches(in: text, options: [], range: NSRange(text.startIndex..., in: text))
            
            for match in matches {
                if let range = Range(match.range(at: 1), in: text) {
                    results.append(String(text[range]))
                }
            }
        } catch {
            print("Error extracting all with pattern \(pattern): \(error)")
        }
        
        return results
    }
    
    private func cleanHTML(_ html: String) -> String {
        return html
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&#8226;", with: "•")
            .replacingOccurrences(of: "&bull;", with: "•")
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&mdash;", with: "—")
            .replacingOccurrences(of: "&ndash;", with: "–")
            .replacingOccurrences(of: "&hellip;", with: "…")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum NewsError: Error {
    case invalidURL
    case invalidData
    case parseError(String)
}