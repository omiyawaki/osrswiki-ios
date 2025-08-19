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
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Main content section (title and snippet)
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.title)
                        .font(.osrsListTitle)
                        .lineLimit(2)
                        .foregroundStyle(.osrsOnSurface)
                        .multilineTextAlignment(.leading)
                        .onAppear {
                            print("🔍 [FONT DEBUG] Title: '\(result.title)'")
                            print("🔍 [FONT DEBUG] Title using .osrsListTitle (Alegreya-Medium 20pt)")
                        }
                    
                    if let snippet = result.snippet, !snippet.isEmpty {
                        Text(snippet.htmlToAttributedString())
                            .font(.subheadline)
                            .lineLimit(2)
                            .foregroundStyle(.osrsOnSurfaceVariant)
                            .multilineTextAlignment(.leading)
                            .onAppear {
                                print("🔍 [SNIPPET DEBUG] Title: '\(result.title)'")
                                print("🔍 [SNIPPET DEBUG] Raw snippet: '\(snippet)'")
                                print("🔍 [SNIPPET DEBUG] Contains searchmatch: \(snippet.contains("searchmatch"))")
                            }
                    }
                }
                
                Spacer()
                
                // Thumbnail positioned on the right (matching Android layout)
                AsyncImage(url: result.thumbnailUrl) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .clipped()
                } placeholder: {
                    Image(systemName: "doc.text.fill")
                        .foregroundStyle(.osrsOnSurfaceVariant)
                        .font(.title2)
                }
                .frame(width: 60, height: 60)
                .background(.osrsSurfaceVariant)
                .cornerRadius(8)
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
    VStack {
        // Test different font configurations
        Text("Testing System .headline font")
            .font(.headline)
            .padding()
        
        Text("Testing OSRS Alegreya title font") 
            .font(.osrsListTitle)
            .padding()
            
        Text("HTML Test: <b>Bold text</b> should be bold")
            .font(.subheadline)
            .padding()
            
        Text("HTML Test: <b>Bold text</b> should be bold".htmlToAttributedString())
            .font(.subheadline)
            .padding()
    }
    .onAppear {
        print("🔍 [DEBUG] Preview loaded - checking font availability")
        let testFont = UIFont(name: "Alegreya-Medium", size: 20)
        print("🔍 [DEBUG] Alegreya-Medium available: \(testFont != nil)")
        if let font = testFont {
            print("🔍 [DEBUG] Font name: \(font.fontName), size: \(font.pointSize)")
        }
    }
}

// MARK: - HTML Processing Extension
extension String {
    func htmlToAttributedString() -> AttributedString {
        // DEBUG: Log the conversion process
        print("🔍 [HTML DEBUG] Original snippet: '\(self)'")
        
        // Handle search match highlighting similar to Android 
        // Android uses: <span class="searchmatch"> -> <b><font color='#FF6B35'>
        let orangeColor = "#FF6B35"  // Same as Android's search_highlight_light
        let highlightedHtml = self
            .replacingOccurrences(of: "<span class=\"searchmatch\">", with: "<b><font color='\(orangeColor)'>")
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
        print("🔍 [HTML DEBUG] Target highlight color: \(orangeColor)")
        
        // Apply system font to entire string, preserving other attributes (colors, bold)
        let fullRange = NSRange(location: 0, length: mutableAttributedString.length)
        
        // First, set all text to regular system font (preserving other attributes)
        mutableAttributedString.addAttribute(.font, value: systemFont, range: fullRange)
        
        // Then, find bold ranges and apply bold system font (colors are preserved)
        mutableAttributedString.enumerateAttribute(.font, in: fullRange) { (value, range, _) in
            if let font = value as? UIFont {
                if font.fontDescriptor.symbolicTraits.contains(.traitBold) {
                    mutableAttributedString.addAttribute(.font, value: boldSystemFont, range: range)
                }
            }
        }
        
        let result = AttributedString(mutableAttributedString)
        print("🔍 [HTML DEBUG] Font override SUCCESS - using system fonts")
        
        return result
    }
}