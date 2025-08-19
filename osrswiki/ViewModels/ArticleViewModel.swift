//
//  ArticleViewModel.swift
//  OSRS Wiki
//
//  Created on iOS webviewer implementation session
//  Updated for article rendering parity with Android
//

import SwiftUI
import WebKit
import Combine

// MARK: - Supporting Types

/// Save state enum matching Android PageActionBarManager.SaveState
enum osrsArticleBottomBarSaveState {
    case notSaved
    case downloading
    case saved
    case error
}

@MainActor
class ArticleViewModel: NSObject, ObservableObject {
    @Published var isLoading: Bool = false
    @Published var loadingProgress: Double = 0.0
    @Published var errorMessage: String?
    @Published var pageTitle: String = ""
    @Published var isBookmarked: Bool = false
    @Published var hasTableOfContents: Bool = false
    @Published var tableOfContents: [TableOfContentsSection] = []
    
    // Bottom bar state management - matching Android PageActionBarManager
    @Published var saveState: osrsArticleBottomBarSaveState = .notSaved
    @Published var saveProgress: Double = 0.0
    
    let pageUrl: URL
    let pageTitle_: String?
    let pageId: Int?
    
    weak var webView: WKWebView?
    private var cancellables = Set<AnyCancellable>()
    private var progressObserver: NSKeyValueObservation?
    private let contentLoader = osrsPageContentLoader()
    
    init(pageUrl: URL, pageTitle: String? = nil, pageId: Int? = nil) {
        self.pageUrl = pageUrl
        self.pageTitle_ = pageTitle
        self.pageId = pageId
        super.init()
    }
    
    func setWebView(_ webView: WKWebView) {
        self.webView = webView
        setupWebViewObservers()
    }
    
    private func setupWebViewObservers() {
        guard let webView = webView else { return }
        
        // Observe loading progress
        progressObserver = webView.observe(\.estimatedProgress, options: .new) { [weak self] webView, _ in
            DispatchQueue.main.async {
                self?.loadingProgress = webView.estimatedProgress
                self?.isLoading = webView.estimatedProgress < 1.0
            }
        }
    }
    
    func loadArticle(theme: any osrsThemeProtocol = osrsLightTheme()) {
        guard let webView = webView else { 
            print("❌ ArticleViewModel: WebView not set")
            return 
        }
        
        isLoading = true
        errorMessage = nil
        loadingProgress = 0.05
        
        print("🔗 ArticleViewModel: Loading article with custom HTML building")
        print("🔗 ArticleViewModel: pageUrl=\(pageUrl), pageTitle_=\(pageTitle_ ?? "nil"), pageId=\(pageId?.description ?? "nil")")
        
        // Debug: Print raw title hex bytes to detect encoding issues
        if let rawTitle = pageTitle_ {
            print("🔗 DEBUG: Raw title: '\(rawTitle)'")
            print("🔗 DEBUG: Title UTF-8 bytes: \(rawTitle.utf8.map { String(format: "%02X", $0) }.joined(separator: " "))")
            print("🔗 DEBUG: Title.count: \(rawTitle.count)")
            print("🔗 DEBUG: Title contains %: \(rawTitle.contains("%"))")
            print("🔗 DEBUG: Title contains colon: \(rawTitle.contains(":"))")
        }
        
        // Extract canonical title from URL (like Android does)
        let titleToLoad: String
        if let cleanPageTitle = pageTitle_?.trimmingCharacters(in: .whitespacesAndNewlines), !cleanPageTitle.isEmpty {
            // Use the provided title (for cases like search results)
            print("📄 ArticleViewModel: Using provided title: '\(cleanPageTitle)'")
            
            // Defensive check: detect potential corruption early
            if cleanPageTitle.contains("%20") && !cleanPageTitle.hasPrefix("http") {
                print("⚠️ ArticleViewModel: ALERT - Title contains URL encoding but isn't a URL!")
                print("⚠️ ArticleViewModel: This suggests title corruption - falling back to URL extraction")
                titleToLoad = extractTitleFromUrl(pageUrl)
                print("📄 ArticleViewModel: Extracted title from URL due to corruption: '\(titleToLoad)'")
            } else {
                titleToLoad = cleanUpTitle(cleanPageTitle)
                print("📄 ArticleViewModel: After cleanUpTitle: '\(titleToLoad)'")
            }
        } else {
            // Extract canonical title from URL (like Android does)
            titleToLoad = extractTitleFromUrl(pageUrl)
            print("📄 ArticleViewModel: Extracted canonical title from URL: '\(titleToLoad)'")
        }
        
        // NOTE: Using direct loading approach instead of publisher pattern
        
        // Simplified direct loading approach
        Task {
            do {
                print("🔄 ArticleViewModel: Starting direct content loading...")
                
                // Update progress
                await MainActor.run {
                    self.loadingProgress = 0.1
                }
                
                // Build URL using actual title
                let encodedTitle = titleToLoad.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? titleToLoad
                let urlString = "https://oldschool.runescape.wiki/api.php?action=parse&format=json&prop=text|displaytitle|revid&disablelimitreport=1&wrapoutputclass=mw-parser-output&page=\(encodedTitle)"
                
                guard let url = URL(string: urlString) else {
                    await MainActor.run {
                        self.errorMessage = "Invalid URL"
                        self.isLoading = false
                    }
                    return
                }
                
                print("🌐 ArticleViewModel: Requesting title: '\(titleToLoad)'")
                print("🌐 ArticleViewModel: Encoded as: '\(encodedTitle)'")
                print("🌐 ArticleViewModel: Full URL: \(urlString)")
                
                // Update progress
                await MainActor.run {
                    self.loadingProgress = 0.3
                }
                
                let (data, _) = try await URLSession.shared.data(from: url)
                
                // Update progress
                await MainActor.run {
                    self.loadingProgress = 0.5
                }
                
                // Parse JSON manually to handle the nested structure
                print("📊 ArticleViewModel: Received data: \(data.count) bytes")
                
                // First, let's see what we actually received
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("📄 ArticleViewModel: Raw JSON (first 500 chars): \(String(jsonString.prefix(500)))")
                }
                
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    throw NSError(domain: "ArticleViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Response is not valid JSON"])
                }
                
                print("📋 ArticleViewModel: JSON keys: \(Array(json.keys))")
                
                // Check if we have an error response
                if let error = json["error"] as? [String: Any] {
                    let code = error["code"] as? String ?? "unknown"
                    let info = error["info"] as? String ?? "Unknown error"
                    throw NSError(domain: "ArticleViewModel", code: -3, userInfo: [NSLocalizedDescriptionKey: "API Error: \(code) - \(info)"])
                }
                
                guard let parse = json["parse"] as? [String: Any] else {
                    throw NSError(domain: "ArticleViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "No 'parse' object in JSON response"])
                }
                
                guard let title = parse["title"] as? String,
                      let pageid = parse["pageid"] as? Int,
                      let textObj = parse["text"] as? [String: Any],
                      let htmlContent = textObj["*"] as? String else {
                    throw NSError(domain: "ArticleViewModel", code: -2, userInfo: [NSLocalizedDescriptionKey: "Missing required fields in API response"])
                }
                
                let displaytitle = parse["displaytitle"] as? String
                let revid = parse["revid"] as? Int
                
                print("✅ ArticleViewModel: Got content - Title: '\(title)', Length: \(htmlContent.count)")
                
                // Update progress
                await MainActor.run {
                    self.loadingProgress = 0.7
                }
                
                // Build HTML using the HTML builder directly
                let htmlBuilder = osrsPageHtmlBuilder()
                let finalHtml = htmlBuilder.buildFullHtmlDocument(
                    title: displaytitle ?? title,
                    bodyContent: htmlContent,
                    theme: theme,
                    collapseTablesEnabled: true
                )
                
                print("🏗️ ArticleViewModel: Built HTML document (\(finalHtml.count) characters)")
                
                // Load in WebView on main thread
                await MainActor.run {
                    self.loadingProgress = 0.9
                    self.pageTitle = displaytitle ?? title
                    self.loadCustomHtml(finalHtml)
                }
                
            } catch {
                print("❌ ArticleViewModel: Direct loading failed: \(error)")
                await MainActor.run {
                    self.errorMessage = "Failed to load content: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
    
    func reloadArticle(theme: any osrsThemeProtocol = osrsLightTheme()) {
        loadArticle(theme: theme)
    }
    
    private func handleDownloadProgress(_ progress: osrsDownloadProgress, theme: any osrsThemeProtocol) {
        switch progress {
        case .fetchingHtml(let progressValue):
            let scaledProgress = 0.05 + (Double(progressValue) * 0.05)
            loadingProgress = scaledProgress
            print("📥 ArticleViewModel: Fetching HTML \(progressValue)% - scaled to \(Int(scaledProgress * 100))%")
            
        case .fetchingAssets(let progressValue):
            let scaledProgress = 0.10 + (Double(progressValue) * 0.40)
            loadingProgress = scaledProgress
            print("📦 ArticleViewModel: Fetching assets \(progressValue)% - scaled to \(Int(scaledProgress * 100))%")
            
        case .success(let pageContent):
            print("✅ ArticleViewModel: Successfully loaded page content")
            loadingProgress = 0.50
            
            // Build the final HTML document
            let finalHtml = contentLoader.buildFullHtmlDocument(
                pageContent: pageContent,
                theme: theme,
                collapseTablesEnabled: true // TODO: Get from user preferences
            )
            
            print("🏗️ ArticleViewModel: Built custom HTML document (\(finalHtml.count) characters)")
            
            // Update page title
            pageTitle = pageContent.parseResult.displaytitle ?? pageContent.parseResult.title ?? "OSRS Wiki"
            
            // Load the custom HTML in WebView
            loadCustomHtml(finalHtml)
            
        case .failure(let error):
            print("❌ ArticleViewModel: Failed to load content: \(error.localizedDescription)")
            isLoading = false
            errorMessage = "Failed to load page: \(error.localizedDescription)"
        }
    }
    
    private func loadCustomHtml(_ html: String) {
        guard let webView = webView else { return }
        
        print("🌐 ArticleViewModel: Loading custom HTML in WebView")
        print("🌐 ArticleViewModel: HTML content length: \(html.count) characters")
        
        // Enhanced loading with improved CSS/JS injection from test environment learnings
        let enhancedHtml = buildEnhancedHtmlWithWorkingCSS(originalHtml: html)
        
        // Use Android-style loading with proper base URL
        let baseURL = URL(string: "https://oldschool.runescape.wiki/")!
        print("🌐 ArticleViewModel: Loading with baseURL: \(baseURL)")
        
        webView.loadHTMLString(enhancedHtml, baseURL: baseURL)
        
        // Reveal body after loading, like Android does
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            print("🌐 ArticleViewModel: Revealing body and completing load...")
            self.revealBody(webView: webView)
            
            // Complete the loading process
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.isLoading = false
                self.loadingProgress = 1.0
                print("✅ ArticleViewModel: Loading completed!")
            }
        }
    }
    
    private func buildEnhancedHtmlWithWorkingCSS(originalHtml: String) -> String {
        print("🎨 ArticleViewModel: Building enhanced HTML with working CSS/JS system")
        
        // Load and verify CSS/JS assets from bundle (like the working test environment)
        let cssContent = loadAllCSSAssets()
        let jsContent = loadAllJSAssets()
        
        print("🎨 ArticleViewModel: Loaded \(cssContent.count) chars CSS, \(jsContent.count) chars JS")
        
        // Extract body content from original HTML
        let bodyContent = extractBodyContent(from: originalHtml)
        let titleContent = extractTitleContent(from: originalHtml) ?? pageTitle
        
        // Build final HTML with working inline styles that render properly
        let finalHtml = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>\(titleContent)</title>
            <style>
                \(cssContent)
                
                /* Enhanced dark theme styles that actually work */
                body {
                    background-color: #1a1a1a !important;
                    color: #ffffff !important;
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                    line-height: 1.6;
                    margin: 0;
                    padding: 20px;
                }
                
                .page-header {
                    color: #ffd700 !important;
                    background: #2d2d2d !important;
                    padding: 15px !important;
                    margin: 0 0 20px 0 !important;
                    border-radius: 8px !important;
                }
                
                .wikitable {
                    background-color: #333 !important;
                    border: 2px solid #666 !important;
                    color: #ffffff !important;
                }
                
                .wikitable th {
                    background-color: #444 !important;
                    color: #ffd700 !important;
                    border: 1px solid #666 !important;
                }
                
                .wikitable td {
                    background-color: #2a2a2a !important;
                    border: 1px solid #666 !important;
                    color: #ffffff !important;
                }
                
                a {
                    color: #66b3ff !important;
                }
                
                a:visited {
                    color: #bb99ff !important;
                }
                
                /* Infobox styling */
                .infobox {
                    background-color: #2d2d2d !important;
                    border: 2px solid #666 !important;
                    color: #ffffff !important;
                }
                
                .infobox-header {
                    background-color: #444 !important;
                    color: #ffd700 !important;
                }
            </style>
        </head>
        <body style="visibility: hidden;">
            \(bodyContent)
            <script>
                \(jsContent)
                
                // Enhanced console debugging
                console.log('🎉 ArticleViewModel: Enhanced HTML with working CSS loaded successfully!');
                
                // Theme application
                document.body.classList.add('theme-osrs-dark');
                
                // Make page visible
                document.body.style.visibility = 'visible';
            </script>
        </body>
        </html>
        """
        
        print("🎨 ArticleViewModel: Built enhanced HTML document (\(finalHtml.count) characters)")
        return finalHtml
    }
    
    private func loadAllCSSAssets() -> String {
        let cssFiles = [
            "styles/themes.css",
            "styles/base.css", 
            "styles/fonts.css",
            "styles/layout.css",
            "styles/components.css",
            "styles/wiki-integration.css",
            "styles/navbox_styles.css",
            "styles/collapsible_tables.css",
            "web/collapsible_sections.css",
            "styles/infobox_switcher.css",
            "styles/fixes.css"
        ]
        
        var combinedCSS = ""
        var loadedCount = 0
        
        for cssFile in cssFiles {
            if let path = Bundle.main.path(forResource: cssFile.replacingOccurrences(of: ".css", with: ""), ofType: "css", inDirectory: cssFile.contains("/") ? String(cssFile.prefix(upTo: cssFile.lastIndex(of: "/")!)) : nil),
               let content = try? String(contentsOfFile: path) {
                combinedCSS += content + "\n"
                loadedCount += 1
                print("✅ ArticleViewModel: Loaded CSS asset: \(cssFile)")
            } else {
                print("❌ ArticleViewModel: Failed to load CSS asset: \(cssFile)")
            }
        }
        
        print("📊 ArticleViewModel: Successfully loaded \(loadedCount)/\(cssFiles.count) CSS files")
        return combinedCSS
    }
    
    private func loadAllJSAssets() -> String {
        let jsFiles = [
            "startup.js",
            "js/tablesort.min.js",
            "js/tablesort_init.js", 
            "web/collapsible_content.js",
            "web/infobox_switcher_bootstrap.js",
            "web/switch_infobox.js",
            "web/horizontal_scroll_interceptor.js",
            "web/responsive_videos.js",
            "web/clipboard_bridge.js"
        ]
        
        var combinedJS = ""
        var loadedCount = 0
        
        for jsFile in jsFiles {
            if let path = Bundle.main.path(forResource: jsFile.replacingOccurrences(of: ".js", with: ""), ofType: "js", inDirectory: jsFile.contains("/") ? String(jsFile.prefix(upTo: jsFile.lastIndex(of: "/")!)) : nil),
               let content = try? String(contentsOfFile: path) {
                combinedJS += content + "\n"
                loadedCount += 1
                print("✅ ArticleViewModel: Loaded JS asset: \(jsFile)")
            } else {
                print("❌ ArticleViewModel: Failed to load JS asset: \(jsFile)")
            }
        }
        
        print("📊 ArticleViewModel: Successfully loaded \(loadedCount)/\(jsFiles.count) JS files")
        return combinedJS
    }
    
    private func extractBodyContent(from html: String) -> String {
        // Extract content between <body> tags
        if let bodyStart = html.range(of: "<body", options: .caseInsensitive),
           let bodyTagEnd = html.range(of: ">", range: bodyStart.upperBound..<html.endIndex),
           let bodyEnd = html.range(of: "</body>", options: .caseInsensitive) {
            return String(html[bodyTagEnd.upperBound..<bodyEnd.lowerBound])
        }
        
        // If no body tags found, return the entire HTML as content
        return html
    }
    
    private func extractTitleContent(from html: String) -> String? {
        // Extract title from HTML
        if let titleStart = html.range(of: "<title>", options: .caseInsensitive),
           let titleEnd = html.range(of: "</title>", options: .caseInsensitive) {
            return String(html[titleStart.upperBound..<titleEnd.lowerBound])
        }
        return nil
    }
    
    private func loadTestHtml() {
        print("🧪 ArticleViewModel: Loading test HTML")
        
        let testHtml = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Test Article</title>
            <style>
                body { 
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                    margin: 0;
                    padding: 20px;
                    background-color: #FF0000 !important;
                    color: #FFFFFF !important;
                    min-height: 100vh;
                }
                h1 { 
                    color: #FFFF00 !important;
                    background: #000000;
                    padding: 10px;
                    margin: 0 0 20px 0;
                }
                .test-content { 
                    background: #0000FF !important;
                    color: #FFFFFF !important;
                    padding: 20px; 
                    border: 3px solid #FFFFFF;
                    margin: 20px 0;
                }
                p, li { color: #FFFFFF !important; }
                code { 
                    background: #FFFF00 !important;
                    color: #000000 !important;
                    padding: 2px 4px;
                }
            </style>
        </head>
        <body style="visibility: hidden;">
            <h1>🧪 DEBUG: Test Article Loaded Successfully!</h1>
            <div class="test-content">
                <p><strong>SUCCESS!</strong> If you can see this colorful test page, the custom HTML loading is working!</p>
                <p>Original URL: <code>\(pageUrl.absoluteString)</code></p>
                <p>Page Title: <code>\(pageTitle_ ?? "nil")</code></p>
                <p>Page ID: <code>\(pageId?.description ?? "nil")</code></p>
                <p>Status Check:</p>
                <ul>
                    <li>✅ ArticleViewModel.loadArticle() was called</li>
                    <li>✅ loadTestHtml() was executed</li>
                    <li>✅ WebView.loadHTMLString() was called</li>
                    <li>✅ HTML is rendering in WebView</li>
                </ul>
                <p><strong>Next step:</strong> Debug the actual wiki API loading mechanism...</p>
            </div>
            <script>
                console.log('🧪 Test HTML loaded successfully!');
                document.body.style.visibility = 'visible';
            </script>
        </body>
        </html>
        """
        
        print("🧪 ArticleViewModel: About to call loadHTMLString")
        print("🧪 ArticleViewModel: webView is \(webView == nil ? "nil" : "not nil")")
        
        if let webView = webView {
            print("🧪 ArticleViewModel: Calling webView.loadHTMLString with \(testHtml.count) characters...")
            
            // Use proper base URL like Android does - create a local asset domain
            let baseURL = URL(string: "https://oldschool.runescape.wiki/")!
            webView.loadHTMLString(testHtml, baseURL: baseURL)
            print("🧪 ArticleViewModel: loadHTMLString called successfully with baseURL: \(baseURL)")
            
            // After loading, reveal the body like Android does
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                print("🧪 ArticleViewModel: Revealing body content...")
                self.revealBody(webView: webView)
            }
        } else {
            print("❌ ArticleViewModel: webView is nil! Cannot load HTML")
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.isLoading = false
            self.loadingProgress = 1.0
            self.pageTitle = "Test Article"
        }
    }
    
    private func revealBody(webView: WKWebView) {
        let revealBodyJs = "document.body.style.visibility = 'visible';"
        print("🧪 ArticleViewModel: Executing JavaScript to reveal body...")
        webView.evaluateJavaScript(revealBodyJs) { result, error in
            if let error = error {
                print("❌ ArticleViewModel: Error revealing body: \(error)")
            } else {
                print("✅ ArticleViewModel: Body revealed successfully!")
            }
        }
    }
    
    private func extractTitleFromUrl(_ url: URL) -> String {
        // Extract article title from wiki URL
        // Examples:
        // https://oldschool.runescape.wiki/w/Dragon -> "Dragon"
        // https://oldschool.runescape.wiki/w/Update:The_Way_of_the_Forester -> "Update:The Way of the Forester"
        // https://oldschool.runescape.wiki/?curid=123 -> fall back to URL
        
        print("🔗 ArticleViewModel: Processing URL: \(url.absoluteString)")
        
        let path = url.path
        print("🔗 ArticleViewModel: URL path: '\(path)'")
        
        if path.hasPrefix("/w/") {
            let encodedTitle = String(path.dropFirst(3)) // Remove "/w/"
            print("🔗 ArticleViewModel: Raw encoded title: '\(encodedTitle)'")
            
            // First decode any URL encoding
            let partiallyDecoded = encodedTitle.removingPercentEncoding ?? encodedTitle
            print("🔗 ArticleViewModel: After percent decoding: '\(partiallyDecoded)'")
            
            // Then replace underscores with spaces (wiki convention)
            let decodedTitle = partiallyDecoded.replacingOccurrences(of: "_", with: " ")
            print("🔗 ArticleViewModel: Final decoded title: '\(decodedTitle)'")
            
            // Clean up any remaining encoding artifacts
            let cleanTitle = cleanUpTitle(decodedTitle)
            print("🔗 ArticleViewModel: Cleaned title: '\(cleanTitle)'")
            
            return cleanTitle
        }
        
        // For curid URLs, we'd need the pageId which should be passed in init
        let fallback = url.lastPathComponent.removingPercentEncoding ?? url.lastPathComponent
        let cleanFallback = cleanUpTitle(fallback.replacingOccurrences(of: "_", with: " "))
        print("🔗 ArticleViewModel: Using fallback title '\(cleanFallback)' from URL")
        return cleanFallback
    }
    
    private func cleanUpTitle(_ title: String) -> String {
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
    
    func goBack() -> Bool {
        guard let webView = webView, webView.canGoBack else { return false }
        webView.goBack()
        return true
    }
    
    func goForward() -> Bool {
        guard let webView = webView, webView.canGoForward else { return false }
        webView.goForward()
        return true
    }
    
    func toggleBookmark() {
        isBookmarked.toggle()
        // TODO: Implement actual bookmark persistence
    }
    
    func scrollToSection(_ sectionId: String) {
        let javascript = """
            const element = document.getElementById('\(sectionId)');
            if (element) {
                element.scrollIntoView({ behavior: 'smooth', block: 'start' });
            }
        """
        webView?.evaluateJavaScript(javascript)
    }
    
    func clearError() {
        errorMessage = nil
    }
    
    // JavaScript bridge methods
    func injectThemeColors(_ themeManager: osrsThemeManager) {
        let webViewColors = themeManager.getWebViewColors()
        let themeScript = webViewColors.generateJavaScript()
        
        print("🎨 ArticleViewModel: Injecting OSRS theme colors")
        webView?.evaluateJavaScript(themeScript) { result, error in
            if let error = error {
                print("❌ ArticleViewModel: Theme injection failed: \(error)")
            } else {
                print("✅ ArticleViewModel: Theme colors injected successfully")
            }
        }
    }
    
    func extractTableOfContents() {
        let tocScript = """
            (function() {
                const headings = document.querySelectorAll('h1, h2, h3, h4, h5, h6');
                const toc = [];
                
                headings.forEach((heading, index) => {
                    const level = parseInt(heading.tagName.substring(1));
                    const text = heading.textContent.trim();
                    const id = heading.id || 'heading-' + index;
                    
                    if (!heading.id) {
                        heading.id = id;
                    }
                    
                    toc.push({
                        id: id,
                        title: text,
                        level: level
                    });
                });
                
                return JSON.stringify(toc);
            })();
        """
        
        webView?.evaluateJavaScript(tocScript) { [weak self] result, error in
            guard let self = self,
                  let jsonString = result as? String,
                  let jsonData = jsonString.data(using: .utf8) else { return }
            
            do {
                let sections = try JSONDecoder().decode([TableOfContentsSection].self, from: jsonData)
                DispatchQueue.main.async {
                    self.tableOfContents = sections
                    self.hasTableOfContents = !sections.isEmpty
                }
            } catch {
                print("Failed to parse table of contents: \(error)")
            }
        }
    }
    
    deinit {
        progressObserver?.invalidate()
    }
}

// MARK: - WKNavigationDelegate
extension ArticleViewModel: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        print("📄 ArticleViewModel: Started loading")
        isLoading = true
        errorMessage = nil
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        print("✅ ArticleViewModel: Finished loading custom HTML")
        loadingProgress = 1.0
        isLoading = false
        
        // Extract table of contents from the loaded content
        extractTableOfContents()
        
        // Inject styling complete notification similar to Android
        webView.evaluateJavaScript("""
            if (window.RenderTimeline) {
                window.RenderTimeline.log('Event: StylingScriptsComplete');
            }
        """)
        
        print("🎉 ArticleViewModel: Page rendering complete")
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("❌ ArticleViewModel: Navigation failed: \(error.localizedDescription)")
        isLoading = false
        errorMessage = "Failed to load page: \(error.localizedDescription)"
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        print("❌ ArticleViewModel: Provisional navigation failed: \(error.localizedDescription)")
        isLoading = false
        errorMessage = "Failed to load page: \(error.localizedDescription)"
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        // Handle internal vs external links
        if let url = navigationAction.request.url {
            print("🔗 ArticleViewModel: Navigation to: \(url.absoluteString)")
            if shouldOpenExternally(url) {
                print("🚀 ArticleViewModel: Opening externally: \(url.absoluteString)")
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
                return
            }
        }
        
        print("✅ ArticleViewModel: Allowing navigation")
        decisionHandler(.allow)
    }
    
    private func shouldOpenExternally(_ url: URL) -> Bool {
        // Open non-wiki links externally
        let wikiDomains = ["oldschool.runescape.wiki", "runescape.wiki"]
        guard let host = url.host else { return true }
        return !wikiDomains.contains(where: { host.contains($0) })
    }
    
    // MARK: - Bottom Bar Actions
    
    /// Save/bookmark toggle action - matches Android PageReadingListManager functionality
    func performSaveAction() {
        guard saveState != .downloading else { return }
        
        if isBookmarked {
            // Remove from saved pages
            saveState = .downloading
            saveProgress = 0.0
            
            // Simulate unsaving process (replace with actual repository call)
            Task {
                for progress in stride(from: 0.0, through: 1.0, by: 0.1) {
                    await MainActor.run {
                        self.saveProgress = progress
                    }
                    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
                }
                
                await MainActor.run {
                    self.isBookmarked = false
                    self.saveState = .notSaved
                    self.saveProgress = 0.0
                }
            }
        } else {
            // Save for offline reading
            saveState = .downloading
            saveProgress = 0.0
            
            // Simulate saving process (replace with actual repository call)
            Task {
                for progress in stride(from: 0.0, through: 1.0, by: 0.1) {
                    await MainActor.run {
                        self.saveProgress = progress
                    }
                    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
                }
                
                await MainActor.run {
                    self.isBookmarked = true
                    self.saveState = .saved
                    self.saveProgress = 1.0
                }
            }
        }
    }
    
    /// Find in page action - matches Android FindInPageManager functionality
    func performFindInPageAction() {
        guard let webView = webView else { return }
        
        // Expand collapsible sections like Android does
        let expandScript = """
            document.querySelectorAll('.collapsible-closed').forEach(function(e) { 
                e.classList.remove('collapsible-closed'); 
            });
        """
        webView.evaluateJavaScript(expandScript, completionHandler: nil)
        
        // TODO: Implement iOS native find-in-page functionality
        // This would typically use WKWebView's built-in search or a custom overlay
        print("🔍 ArticleViewModel: Find in page requested - expanding collapsible content")
    }
    
    /// Appearance/theme action - matches Android AppearanceSettingsActivity
    func performAppearanceAction() {
        // TODO: Navigate to appearance settings
        // This should open the AppearanceSettingsView
        print("🎨 ArticleViewModel: Appearance settings requested")
    }
    
    /// Contents action - matches Android ContentsHandler functionality  
    func performContentsAction() {
        // This is already handled by the existing table of contents functionality
        // The ArticleView will show the table of contents sheet
        print("📋 ArticleViewModel: Contents requested - hasTableOfContents: \(hasTableOfContents)")
    }
}

// MARK: - Data Models
struct TableOfContentsSection: Codable, Identifiable {
    let id: String
    let title: String
    let level: Int
}