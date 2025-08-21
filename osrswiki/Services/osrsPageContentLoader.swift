//
//  osrsPageContentLoader.swift
//  OSRS Wiki
//
//  Created on article rendering parity session
//

import Foundation
import Combine

// Data models for API responses
struct osrsParseResult: Codable {
    let pageid: Int
    let title: String?
    let displaytitle: String?
    let revid: Int?
    let text: String
    
    enum CodingKeys: String, CodingKey {
        case pageid, title, displaytitle, revid
        case text = "*"
    }
}

struct osrsParseResponse: Codable {
    let parse: osrsParseResult
}

struct osrsPageContent {
    let parseResult: osrsParseResult
    let processedHtml: String
    let backgroundUrls: [String]
}

enum osrsDownloadProgress {
    case fetchingHtml(progress: Int)
    case fetchingAssets(progress: Int)
    case success(osrsPageContent)
    case failure(Error)
}

class osrsPageContentLoader {
    private let htmlBuilder: osrsPageHtmlBuilder
    private let session = URLSession.shared
    
    init() {
        self.htmlBuilder = osrsPageHtmlBuilder()
    }
    
    func loadPageByTitle(_ title: String) -> AnyPublisher<osrsDownloadProgress, Never> {
        return Future<osrsDownloadProgress, Never> { promise in
            Task {
                await self.fetchPageContent(title: title, promise: promise)
            }
        }.eraseToAnyPublisher()
    }
    
    func loadPageById(_ pageId: Int) -> AnyPublisher<osrsDownloadProgress, Never> {
        return Future<osrsDownloadProgress, Never> { promise in
            Task {
                await self.fetchPageContent(pageId: pageId, promise: promise)
            }
        }.eraseToAnyPublisher()
    }
    
    private func fetchPageContent(title: String? = nil, pageId: Int? = nil, promise: @escaping (Result<osrsDownloadProgress, Never>) -> Void) async {
        do {
            // Build API URL
            var urlComponents = URLComponents(string: "https://oldschool.runescape.wiki/api.php")!
            var queryItems = [
                URLQueryItem(name: "action", value: "parse"),
                URLQueryItem(name: "format", value: "json"),
                URLQueryItem(name: "prop", value: "text|displaytitle|revid"),
                URLQueryItem(name: "disablelimitreport", value: "1"),
                URLQueryItem(name: "wrapoutputclass", value: "mw-parser-output")
            ]
            
            if let title = title {
                queryItems.append(URLQueryItem(name: "page", value: title))
            } else if let pageId = pageId {
                queryItems.append(URLQueryItem(name: "pageid", value: String(pageId)))
            }
            
            urlComponents.queryItems = queryItems
            
            guard let url = urlComponents.url else {
                promise(.success(.failure(NSError(domain: "osrsPageContentLoader", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]))))
                return
            }
            
            print("📡 osrsPageContentLoader: Fetching content from: \(url.absoluteString)")
            
            // Emit fetching progress
            promise(.success(.fetchingHtml(progress: 10)))
            
            // Fetch the page content
            let (data, response) = try await session.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                promise(.success(.failure(NSError(domain: "osrsPageContentLoader", code: -2, userInfo: [NSLocalizedDescriptionKey: "HTTP Error"]))))
                return
            }
            
            promise(.success(.fetchingHtml(progress: 50)))
            
            // Parse JSON response
            let parseResponse: osrsParseResponse
            do {
                parseResponse = try JSONDecoder().decode(osrsParseResponse.self, from: data)
            } catch {
                print("❌ osrsPageContentLoader: JSON parsing failed: \(error)")
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("📄 Raw JSON (first 500 chars): \(String(jsonString.prefix(500)))")
                }
                promise(.success(.failure(error)))
                return
            }
            
            let parseResult = parseResponse.parse
            print("📄 osrsPageContentLoader: Successfully fetched page - ID: \(parseResult.pageid), Title: '\(parseResult.title ?? "Unknown")'")
            print("📄 osrsPageContentLoader: HTML content length: \(parseResult.text.count) characters")
            
            promise(.success(.fetchingHtml(progress: 80)))
            
            // Process the HTML content (extract background URLs, clean content, etc.)
            let processedContent = await processHtmlContent(parseResult.text)
            
            promise(.success(.fetchingAssets(progress: 50)))
            
            // For now, we'll assume assets are already available locally
            // In a full implementation, this would download and cache assets
            
            promise(.success(.fetchingAssets(progress: 100)))
            
            // Create the final page content
            let pageContent = osrsPageContent(
                parseResult: parseResult,
                processedHtml: processedContent.html,
                backgroundUrls: processedContent.backgroundUrls
            )
            
            promise(.success(.success(pageContent)))
            
        } catch {
            print("❌ osrsPageContentLoader: Error fetching content: \(error)")
            if let urlError = error as? URLError {
                print("❌ osrsPageContentLoader: URLError details - code: \(urlError.code), description: \(urlError.localizedDescription)")
            }
            promise(.success(.failure(error)))
        }
    }
    
    private func processHtmlContent(_ rawHtml: String) async -> (html: String, backgroundUrls: [String]) {
        // Process the HTML content similar to Android's approach
        
        var processedHtml = rawHtml
        var backgroundUrls: [String] = []
        
        // Extract background image URLs for later downloading
        // This is a simplified version - in practice you'd want more sophisticated URL extraction
        let imageUrlPattern = #"https://oldschool\.runescape\.wiki/images/[^"'\s>]+"#
        if let regex = try? NSRegularExpression(pattern: imageUrlPattern) {
            let matches = regex.matches(in: rawHtml, range: NSRange(location: 0, length: rawHtml.utf16.count))
            for match in matches {
                if let range = Range(match.range, in: rawHtml) {
                    let url = String(rawHtml[range])
                    backgroundUrls.append(url)
                }
            }
        }
        
        // Clean up the HTML content
        // Remove any script tags that might interfere with our custom scripts
        processedHtml = processedHtml.replacingOccurrences(
            of: #"<script[^>]*>.*?</script>"#,
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )
        
        // Remove any link tags for stylesheets (we'll use our own)
        processedHtml = processedHtml.replacingOccurrences(
            of: #"<link[^>]*rel="stylesheet"[^>]*>"#,
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )
        
        // Process any MediaWiki-specific content
        print("🔍 osrsPageContentLoader: HTML before processMediaWikiContent contains 'advanced-data': \(processedHtml.contains("advanced-data"))")
        processedHtml = processMediaWikiContent(processedHtml)
        print("🔍 osrsPageContentLoader: HTML after processMediaWikiContent contains 'advanced-data': \(processedHtml.contains("advanced-data"))")
        
        print("🔧 osrsPageContentLoader: Processed HTML content - found \(backgroundUrls.count) background URLs")
        
        return (html: processedHtml, backgroundUrls: Array(Set(backgroundUrls))) // Remove duplicates
    }
    
    private func processMediaWikiContent(_ html: String) -> String {
        var processedHtml = html
        
        // Remove unwanted infobox sections that should be hidden by default
        // (matching Android's preprocessHtml behavior)
        let selectorsToRemove = [
            "advanced-data",
            "leagues-global-flag",
            "infobox-padding"
        ]
        
        print("🔍 osrsPageContentLoader: Starting removal of unwanted infobox sections")
        
        for selector in selectorsToRemove {
            // Pattern to match <tr> elements with the class anywhere in the class attribute
            // This handles cases like class="advanced-data" or class="foo advanced-data bar"
            let pattern = "<tr[^>]*?class=[\"'][^\"']*?\(selector)[^\"']*?[\"'][^>]*?>.*?</tr>"
            
            do {
                let regex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators])
                let matches = regex.matches(in: processedHtml, range: NSRange(location: 0, length: processedHtml.utf16.count))
                print("🔍 osrsPageContentLoader: Found \(matches.count) matches for selector '\(selector)'")
                
                // Remove matches in reverse order to maintain correct indices
                for match in matches.reversed() {
                    if let range = Range(match.range, in: processedHtml) {
                        let matchedText = String(processedHtml[range])
                        print("🔍 osrsPageContentLoader: Removing element with class '\(selector)': \(matchedText.prefix(100))...")
                        processedHtml.removeSubrange(range)
                    }
                }
            } catch {
                print("❌ osrsPageContentLoader: Failed to create regex for selector '\(selector)': \(error)")
            }
        }
        
        // Convert MediaWiki internal links to app-friendly format
        // Example: [[Dragon]] -> <a href="/w/Dragon">Dragon</a>
        processedHtml = processedHtml.replacingOccurrences(
            of: #"\[\[([^\]|]+)(\|([^\]]+))?\]\]"#,
            with: "<a href=\"/w/$1\">$3</a>",
            options: .regularExpression
        )
        
        // Handle external links
        processedHtml = processedHtml.replacingOccurrences(
            of: #"\[([^\s\]]+) ([^\]]+)\]"#,
            with: "<a href=\"$1\" class=\"external\">$2</a>",
            options: .regularExpression
        )
        
        // Process templates and infoboxes for better mobile display
        // This would be expanded based on specific OSRS wiki patterns
        
        return processedHtml
    }
    
    func buildFullHtmlDocument(pageContent: osrsPageContent, theme: any osrsThemeProtocol, collapseTablesEnabled: Bool = true) -> String {
        let title = pageContent.parseResult.displaytitle ?? pageContent.parseResult.title ?? "OSRS Wiki"
        return htmlBuilder.buildFullHtmlDocument(
            title: title,
            bodyContent: pageContent.processedHtml,
            theme: theme,
            collapseTablesEnabled: collapseTablesEnabled
        )
    }
}