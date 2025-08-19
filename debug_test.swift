import Foundation

// Test title processing with various scenarios
let scenarios = [
    ("Clean title", "Forestry: The Way of the Forester"),
    ("Simple title", "Dragon"),
    ("Title with symbols", "Desert Treasure II - The Fallen Empire"),
    ("Title with URL encoding", "Forestry:%20The%20Way%20of%20the%20Forester"),
    ("Malformed title", "Forestry: %20The%20Way%20of%20the%20-Forester")
]

print("=== iOS Article Title Processing Test ===\n")

print("Original title: '\(testTitle)'")
print("Original URL: \(testUrl)")

// Test what happens when we apply cleanUpTitle
func cleanUpTitle(_ title: String) -> String {
    var cleanTitle = title
    
    // Remove any remaining percent-encoded characters that might have slipped through
    while cleanTitle.contains("%") && cleanTitle != (cleanTitle.removingPercentEncoding ?? cleanTitle) {
        cleanTitle = cleanTitle.removingPercentEncoding ?? cleanTitle
    }
    
    // Clean up common encoding artifacts
    cleanTitle = cleanTitle
        .replacingOccurrences(of: "%20-", with: " ")  // Fix malformed encoding
        .replacingOccurrences(of: "%20", with: " ")   // Any remaining %20
        .replacingOccurrences(of: "%3A", with: ":")   // Colon
        .replacingOccurrences(of: "%2C", with: ",")   // Comma
        .replacingOccurrences(of: "%26", with: "&")   // Ampersand
        .trimmingCharacters(in: .whitespacesAndNewlines)
    
    // Collapse multiple spaces into single spaces
    while cleanTitle.contains("  ") {
        cleanTitle = cleanTitle.replacingOccurrences(of: "  ", with: " ")
    }
    
    return cleanTitle
}

let cleanedTitle = cleanUpTitle(testTitle)
print("After cleanUpTitle: '\(cleanedTitle)'")

// Test URL encoding
let encodedTitle = cleanedTitle.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? cleanedTitle
print("URL encoded: '\(encodedTitle)'")

let urlString = "https://oldschool.runescape.wiki/api.php?action=parse&format=json&prop=text|displaytitle|revid&disablelimitreport=1&wrapoutputclass=mw-parser-output&page=\(encodedTitle)"
print("Final API URL: \(urlString)")
