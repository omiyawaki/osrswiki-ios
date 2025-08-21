//
//  SearchResultRowView.swift
//  OSRS Wiki
//
//  Created on iOS theming fixes session
//

import SwiftUI
import Foundation

struct SearchResultRowView: View {
    @Environment(\.osrsTheme) var osrsTheme
    let result: ThemedSearchResult
    let searchQuery: String?
    let onTap: () -> Void
    
    private var highlightedTitle: AttributedString {
        guard let searchQuery = searchQuery, !searchQuery.isEmpty else {
            return AttributedString(result.title)
        }
        
        // Get the Alegreya font that matches .osrsListTitle
        let alegreyaFont = getAlegreyaFont()
        
        return result.title.highlightMatches(query: searchQuery, 
                                             baseColor: Color(osrsTheme.primaryTextColor),
                                             highlightColor: Color(osrsTheme.secondaryTextColor),
                                             baseFont: alegreyaFont)
    }
    
    private func getAlegreyaFont() -> UIFont {
        let fontNames = ["Alegreya-Medium", "alegreya_medium", "Alegreya Medium", "Alegreya-Regular", "Alegreya Regular"]
        for fontName in fontNames {
            if let font = UIFont(name: fontName, size: 20) {
                return font
            }
        }
        // Fallback to system font if Alegreya is not available
        return UIFont.preferredFont(forTextStyle: .headline)
    }
    
    private var highlightedSnippet: AttributedString {
        guard let snippet = result.snippet, !snippet.isEmpty else {
            return AttributedString("")
        }
        
        // First try HTML processing for any existing searchmatch tags
        let htmlProcessed = snippet.htmlToAttributedString(baseColor: Color(osrsTheme.primaryTextColor))
        
        // If no search query, return HTML processed version
        guard let searchQuery = searchQuery, !searchQuery.isEmpty else {
            return htmlProcessed
        }
        
        // If HTML processing didn't find highlights, do manual highlighting
        let plainText = snippet.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        return plainText.highlightMatches(query: searchQuery,
                                          baseColor: Color(osrsTheme.primaryTextColor),
                                          highlightColor: Color(osrsTheme.secondaryTextColor))
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Main content section (title and snippet)
                VStack(alignment: .leading, spacing: 4) {
                    Text(highlightedTitle)
                        .font(.osrsListTitle)
                        .lineLimit(2)
                        .foregroundStyle(.osrsPrimaryTextColor)
                        .multilineTextAlignment(.leading)
                        .onAppear {
                            print("🔍 [FONT DEBUG] Title: '\(result.title)'")
                            print("🔍 [FONT DEBUG] Title using .osrsListTitle (Alegreya-Medium 20pt)")
                        }
                    
                    if let snippet = result.snippet, !snippet.isEmpty {
                        Text(highlightedSnippet)
                            .font(.subheadline)
                            .lineLimit(2)
                            .foregroundStyle(.osrsSecondaryTextColor)
                            .multilineTextAlignment(.leading)
                            .onAppear {
                                print("🔍 [SNIPPET DEBUG] Title: '\(result.title)'")
                                print("🔍 [SNIPPET DEBUG] Raw snippet: '\(snippet)'")
                                print("🔍 [SNIPPET DEBUG] Contains searchmatch: \(snippet.contains("searchmatch"))")
                                print("🔍 [SNIPPET DEBUG] Search query: '\(searchQuery ?? "nil")'")
                            }
                    }
                }
                
                Spacer()
                
                // Thumbnail positioned on the right (matching Android layout) - only show if URL exists
                if let thumbnailUrl = result.thumbnailUrl {
                    AsyncImage(url: thumbnailUrl) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .clipped()
                    } placeholder: {
                        ProgressView()
                            .frame(width: 60, height: 60)
                    }
                    .frame(width: 60, height: 60)
                    .background(.osrsSearchBoxBackgroundColor)
                    .cornerRadius(8)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .listRowBackground(osrsTheme.surface)
        .listRowSeparator(.visible, edges: .bottom)
        .listRowSeparatorTint(osrsTheme.divider)
    }
}

// MARK: - ThemedSearchResult Model
struct ThemedSearchResult: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let snippet: String?
    let description: String?
    let url: String
    let thumbnailUrl: URL?
    let pageId: Int?
    
    init(title: String, snippet: String? = nil, description: String? = nil, url: String, thumbnailUrl: URL? = nil, pageId: Int? = nil) {
        self.title = title
        self.snippet = snippet
        self.description = description
        self.url = url
        self.thumbnailUrl = thumbnailUrl
        self.pageId = pageId
    }
}

#Preview {
    SearchResultRowView(
        result: ThemedSearchResult(
            title: "Varrock Castle",
            snippet: "Varrock is the capital city of the kingdom...",
            description: "Article",
            url: "https://example.com",
            thumbnailUrl: nil,
            pageId: 123
        ),
        searchQuery: "var"
    ) {
        print("Tapped result")
    }
    .environmentObject(osrsThemeManager.preview)
    .environment(\.osrsTheme, osrsLightTheme())
}

// MARK: - HTML Processing Extension
extension String {
    func htmlToAttributedString(baseColor: Color = .primary) -> AttributedString {
        // DEBUG: Log the conversion process
        print("🔍 [HTML DEBUG] Original snippet: '\(self)'")
        
        // Handle search match highlighting with unified brown color
        // Use same brown as osrs_text_secondary_light (#8B7355) to match Android
        let brownColor = "#8B7355"  // Unified highlight color across platforms
        let highlightedHtml = self
            .replacingOccurrences(of: "<span class=\"searchmatch\">", with: "<b><font color='\(brownColor)'>")
            .replacingOccurrences(of: "</span>", with: "</font></b>")
        
        print("🔍 [HTML DEBUG] After HTML transformation: '\(highlightedHtml)'")
        
        // Convert HTML to AttributedString
        guard let data = highlightedHtml.data(using: .utf8),
              let attributedString = try? NSAttributedString(
                data: data,
                options: [.documentType: NSAttributedString.DocumentType.html,
                         .characterEncoding: String.Encoding.utf8.rawValue],
                documentAttributes: nil
              ) else {
            // Fallback to plain text if HTML parsing fails
            print("🔍 [HTML DEBUG] HTML parsing FAILED - using plain text fallback")
            return AttributedString(self)
        }
        
        // Create mutable copy to override font attributes while preserving colors
        let mutableAttributedString = NSMutableAttributedString(attributedString: attributedString)
        
        // Get the system subheadline font to match SwiftUI's .subheadline
        let systemFont = UIFont.preferredFont(forTextStyle: .subheadline)
        let boldSystemFont = UIFont.boldSystemFont(ofSize: systemFont.pointSize)
        
        print("🔍 [HTML DEBUG] Setting fonts - Regular: \(systemFont.fontName), Bold: \(boldSystemFont.fontName)")
        print("🔍 [HTML DEBUG] Target highlight color: \(brownColor)")
        
        // Apply system font to entire string, preserving existing colors
        let fullRange = NSRange(location: 0, length: mutableAttributedString.length)
        
        // Store existing color attributes BEFORE making font changes
        var colorRanges: [(NSRange, UIColor)] = []
        mutableAttributedString.enumerateAttribute(.foregroundColor, in: fullRange) { (value, range, _) in
            if let color = value as? UIColor {
                colorRanges.append((range, color))
            }
        }
        
        // Apply system font to entire string
        mutableAttributedString.addAttribute(.font, value: systemFont, range: fullRange)
        
        // Apply bold system font to bold ranges
        mutableAttributedString.enumerateAttribute(.font, in: fullRange) { (value, range, _) in
            if let font = value as? UIFont {
                if font.fontDescriptor.symbolicTraits.contains(.traitBold) {
                    mutableAttributedString.addAttribute(.font, value: boldSystemFont, range: range)
                }
            }
        }
        
        // Apply colors: use base color for ranges without existing colors, preserve highlights
        mutableAttributedString.addAttribute(.foregroundColor, value: UIColor(baseColor), range: fullRange)
        
        // Restore specific highlight colors (they should be orange from HTML processing)
        for (range, color) in colorRanges {
            // Check if this is likely a highlight color (not black/default)
            let colorComponents = color.cgColor.components
            let isLikelyHighlight = colorComponents?.count ?? 0 >= 3 && 
                                   (colorComponents?[0] ?? 0) > 0.3 && // Some red component
                                   (colorComponents?[1] ?? 0) > 0.2 && // Some green component  
                                   color != UIColor.black && color != UIColor.label
            
            if isLikelyHighlight {
                mutableAttributedString.addAttribute(.foregroundColor, value: color, range: range)
                print("🔍 [HIGHLIGHT] Preserved highlight color at range \(range): \(color)")
            }
        }
        
        let result = AttributedString(mutableAttributedString)
        print("🔍 [HTML DEBUG] Font override SUCCESS - using system fonts")
        
        return result
    }
}

// MARK: - Manual Text Highlighting Extension
extension String {
    func highlightMatches(query: String, baseColor: Color, highlightColor: Color, baseFont: UIFont? = nil) -> AttributedString {
        let attributedString = NSMutableAttributedString(string: self)
        let fullRange = NSRange(location: 0, length: attributedString.length)
        
        // Set base color and font
        let font = baseFont ?? UIFont.preferredFont(forTextStyle: .subheadline)
        let boldFont = baseFont?.withTraits(.traitBold) ?? UIFont.boldSystemFont(ofSize: font.pointSize)
        attributedString.addAttribute(.font, value: font, range: fullRange)
        attributedString.addAttribute(.foregroundColor, value: UIColor(baseColor), range: fullRange)
        
        // Find and highlight matches (case insensitive)
        let searchString = self.lowercased()
        let queryLowercased = query.lowercased()
        
        var searchIndex = 0
        while searchIndex < searchString.count {
            let startIndex = searchString.index(searchString.startIndex, offsetBy: searchIndex)
            if let range = searchString.range(of: queryLowercased, range: startIndex..<searchString.endIndex) {
                let nsRange = NSRange(range, in: self)
                
                // Apply highlight color and bold
                attributedString.addAttribute(.foregroundColor, value: UIColor(highlightColor), range: nsRange)
                attributedString.addAttribute(.font, value: boldFont, range: nsRange)
                
                searchIndex = self.distance(from: self.startIndex, to: range.upperBound)
                print("🔍 [HIGHLIGHT] Found match '\(queryLowercased)' in '\(self)' at range: \(nsRange)")
            } else {
                break
            }
        }
        
        return AttributedString(attributedString)
    }
}

// MARK: - UIFont Extension for Bold Traits
extension UIFont {
    func withTraits(_ traits: UIFontDescriptor.SymbolicTraits) -> UIFont? {
        let descriptor = fontDescriptor.withSymbolicTraits(traits)
        return descriptor.map { UIFont(descriptor: $0, size: 0) }
    }
}