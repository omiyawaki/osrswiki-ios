//
//  osrsSimplePageLoader.swift
//  OSRS Wiki
//
//  Created for debugging article loading issues
//

import Foundation

class osrsSimplePageLoader {
    
    static func testLoadPage(title: String) async {
        print("🧪 SimpleLoader: Testing page load for '\(title)'")
        
        let urlString = "https://oldschool.runescape.wiki/api.php?action=parse&format=json&prop=text|displaytitle|revid&disablelimitreport=1&wrapoutputclass=mw-parser-output&page=\(title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? title)"
        
        guard let url = URL(string: urlString) else {
            print("❌ SimpleLoader: Invalid URL")
            return
        }
        
        print("🌐 SimpleLoader: Fetching from: \(urlString)")
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 SimpleLoader: HTTP Status: \(httpResponse.statusCode)")
            }
            
            print("📊 SimpleLoader: Data size: \(data.count) bytes")
            
            // Try to parse as JSON
            do {
                let json = try JSONSerialization.jsonObject(with: data, options: [])
                print("✅ SimpleLoader: JSON parsing successful")
                
                if let dict = json as? [String: Any],
                   let parse = dict["parse"] as? [String: Any] {
                    print("📋 SimpleLoader: Found parse object")
                    
                    if let title = parse["title"] as? String {
                        print("📝 SimpleLoader: Title: \(title)")
                    }
                    
                    if let text = parse["text"] as? [String: Any],
                       let content = text["*"] as? String {
                        print("📄 SimpleLoader: Content length: \(content.count) characters")
                        print("📄 SimpleLoader: Content preview: \(String(content.prefix(100)))")
                    } else {
                        print("❌ SimpleLoader: Could not extract text content")
                        print("📋 SimpleLoader: Text structure: \(parse["text"] ?? "nil")")
                    }
                }
            } catch {
                print("❌ SimpleLoader: JSON parsing failed: \(error)")
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("📄 SimpleLoader: Raw JSON (first 200 chars): \(String(jsonString.prefix(200)))")
                }
            }
            
        } catch {
            print("❌ SimpleLoader: Network error: \(error)")
        }
        
        print("🧪 SimpleLoader: Test complete")
    }
}