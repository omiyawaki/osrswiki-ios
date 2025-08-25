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

// TIMELINE LOGGING: Precise timestamp formatter for tracking loading phases
extension DateFormatter {
    static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()
}

// MARK: - Notification Names
extension Notification.Name {
    static let showAppearanceSettings = Notification.Name("showAppearanceSettings")
}

// MARK: - Color Extension for Hex Conversion
extension Color {
    func toHexString() -> String {
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        let r = Int(red * 255.0)
        let g = Int(green * 255.0)
        let b = Int(blue * 255.0)
        
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

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
    @Published var loadingProgressText: String? = nil
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
    let collapseTablesEnabled: Bool
    let snippet_: String?  // Metadata for rich history display
    let thumbnailUrl_: URL?  // Metadata for rich history display
    
    weak var webView: WKWebView?
    private var cancellables = Set<AnyCancellable>()
    private var progressObserver: NSKeyValueObservation?
    private let contentLoader = osrsPageContentLoader()
    private let savedPagesRepository = SavedPagesRepository()
    private let historyRepository = HistoryRepository()
    
    // TIMING MEASUREMENT: Track progress completion vs page visibility delay
    var progressCompletionTime: Date?
    private var pageVisibilityTime: Date?
    @Published var lastMeasuredDelay: TimeInterval? = nil
    
    init(pageUrl: URL, pageTitle: String? = nil, pageId: Int? = nil, snippet: String? = nil, thumbnailUrl: URL? = nil, collapseTablesEnabled: Bool = true) {
        self.pageUrl = pageUrl
        self.pageTitle_ = pageTitle
        self.pageId = pageId
        self.collapseTablesEnabled = collapseTablesEnabled
        self.snippet_ = snippet
        self.thumbnailUrl_ = thumbnailUrl
        super.init()
    }
    
    func setWebView(_ webView: WKWebView) {
        self.webView = webView
        setupWebViewObservers()
        checkIfPageIsSaved()
    }
    
    private func setupWebViewObservers() {
        guard let webView = webView else { return }
        
        // Smart progress mapping - embed WebKit's automatic progress into total progress phases
        // This matches Android's approach: map WebView 0-100% to appropriate phase ranges
        progressObserver = webView.observe(\.estimatedProgress, options: .new) { [weak self] webView, _ in
            DispatchQueue.main.async {
                self?.updateProgressFromWebKit(webView.estimatedProgress)
            }
        }
    }
    
    // Smart progress mapping matching Android's implementation  
    private func updateProgressFromWebKit(_ webKitProgress: Double) {
        let webKitPercent = Int(webKitProgress * 100)
        let timestamp = Date()
        let timeString = DateFormatter.timeFormatter.string(from: timestamp)
        
        if isLoading {
            // Map WebKit progress to appropriate phase based on current loading stage
            let mappedProgress: Double
            let progressText: String
            
            if webKitPercent < 10 {
                // Initial loading phase: 0-10% WebKit -> 5-15% total
                mappedProgress = 0.05 + (webKitProgress * 0.1)
                progressText = "Starting download..."
            } else if webKitPercent < 50 {
                // Content fetching phase: 10-50% WebKit -> 15-50% total  
                mappedProgress = 0.15 + ((webKitProgress - 0.1) * 0.875) // 0.875 = (0.5-0.15)/(0.5-0.1)
                progressText = "Downloading content..."
            } else if webKitPercent < 95 {
                // Rendering phase: 50-95% WebKit -> 50-95% total
                mappedProgress = 0.5 + ((webKitProgress - 0.5) * 1.0) 
                progressText = "Rendering page..."
            } else {
                // ANDROID PARITY: Cap at 95% until JavaScript signals content ready
                mappedProgress = 0.95
                progressText = "Finalizing content..."
            }
            
            self.loadingProgress = mappedProgress
            self.loadingProgressText = progressText
            
            // ANDROID PARITY: Don't complete on WebKit 100% - wait for JavaScript signal
            if webKitProgress >= 1.0 {
                // TIMING MEASUREMENT: Record when WebKit completes (not final completion)
                self.progressCompletionTime = timestamp
                print("📊 [\(timeString)] 🔴 WEBKIT COMPLETE: WebKit reached 100%, waiting for JavaScript content readiness...")
                
                // Progress stays at 95% and loading continues until "StylingScriptsComplete"
                self.loadingProgress = 0.95
                self.loadingProgressText = "Finalizing content..."
                self.isLoading = true
            } else {
                self.isLoading = true
            }
            
            print("📊 [\(timeString)] Progress mapping: WebKit \(Int(webKitProgress * 100))% -> Total \(Int(mappedProgress * 100))% (\(progressText))")
        }
    }
    
    func loadArticle(theme: any osrsThemeProtocol = osrsLightTheme()) {
        guard let webView = webView else { 
            print("❌ ArticleViewModel: WebView not set")
            return 
        }
        
        isLoading = true
        errorMessage = nil
        
        // TIMING MEASUREMENT: Reset timing measurements for new page load
        progressCompletionTime = nil
        pageVisibilityTime = nil
        
        // Initial progress will be set by WebKit observer
        
        let timeString = DateFormatter.timeFormatter.string(from: Date())
        print("📊 [\(timeString)] 🚀 LOADING STARTED: Beginning article load process")
        print("📊 [\(timeString)] 📋 LOAD PARAMS: pageUrl=\(pageUrl), pageTitle=\(pageTitle_ ?? "nil"), pageId=\(pageId?.description ?? "nil")")
        
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
                
                // Progress will be updated automatically by WebKit observer
                
                // CRITICAL FIX: Extract page name from URL, convert underscores to spaces
                // MediaWiki API expects display title (spaces), not URL path (underscores)
                let originalUrlString = pageUrl.absoluteString
                let pageTitle: String
                if let range = originalUrlString.range(of: "/w/") {
                    let urlPageName = String(originalUrlString[range.upperBound...])
                    // Convert URL encoding back to display title: %26 -> &, _ -> space
                    pageTitle = urlPageName.removingPercentEncoding?.replacingOccurrences(of: "_", with: " ") ?? titleToLoad
                } else {
                    // Fallback to extracted title
                    pageTitle = titleToLoad
                }
                
                // FIXED: Use URLComponents to avoid double-encoding
                var components = URLComponents(string: "https://oldschool.runescape.wiki/api.php")!
                components.queryItems = [
                    URLQueryItem(name: "action", value: "parse"),
                    URLQueryItem(name: "format", value: "json"),
                    URLQueryItem(name: "prop", value: "text|displaytitle|revid"),
                    URLQueryItem(name: "disablelimitreport", value: "1"),
                    URLQueryItem(name: "wrapoutputclass", value: "mw-parser-output"),
                    URLQueryItem(name: "page", value: pageTitle)  // No pre-encoding needed!
                ]
                
                guard let url = components.url else {
                    await MainActor.run {
                        self.errorMessage = "Invalid URL"
                        self.isLoading = false
                    }
                    return
                }
                
                print("🌐 ArticleViewModel: Extracted page title: '\(pageTitle)'")
                print("🌐 ArticleViewModel: URLComponents URL: '\(url.absoluteString)'")
                
                // Progress updated automatically by WebKit observer
                
                let (data, _) = try await URLSession.shared.data(from: url)
                
                // Progress updated automatically by WebKit observer
                
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
                
                // Progress updated automatically by WebKit observer
                
                // Process the HTML to remove unwanted sections (matching Android behavior)
                let processedHtml = removeUnwantedInfoboxSections(from: htmlContent)
                print("📄 ArticleViewModel: Processed HTML - removed unwanted sections")
                
                // Build HTML using the HTML builder directly (without asset links for WKUserScript injection)
                let htmlBuilder = osrsPageHtmlBuilder()
                let finalHtml = htmlBuilder.buildFullHtmlDocument(
                    title: displaytitle ?? title,
                    bodyContent: processedHtml,
                    theme: theme,
                    collapseTablesEnabled: collapseTablesEnabled,
                    includeAssetLinks: true   // Option B: Generate <link> and <script> tags for ios-assets:// URLs
                )
                
                print("🏗️ ArticleViewModel: Built HTML document (\(finalHtml.count) characters)")
                
                // DEBUG: Check if the correct custom scheme URLs are in the HTML
                let expectedScheme = UserDefaults.standard.string(forKey: "WKURLSchemeHandler_Scheme") ?? "app-assets"
                print("🔍 Checking HTML for scheme: \(expectedScheme)://")
                
                if finalHtml.contains("\(expectedScheme)://") {
                    print("✅ HTML contains \(expectedScheme):// URLs")
                    let customLinks = finalHtml.components(separatedBy: "\n").filter { $0.contains("\(expectedScheme)://") }
                    print("📋 Found \(customLinks.count) \(expectedScheme):// links in HTML")
                    if customLinks.count > 0 {
                        print("📋 First few links: \(customLinks.prefix(3))")
                    }
                } else {
                    print("❌ HTML does NOT contain \(expectedScheme):// URLs - Option B not working!")
                    // Check what schemes are actually in the HTML
                    if finalHtml.contains("://") {
                        let allSchemes = finalHtml.components(separatedBy: "\n")
                            .filter { $0.contains("://") }
                            .compactMap { line in
                                let components = line.components(separatedBy: "://")
                                return components.count > 1 ? components[0].components(separatedBy: "\"").last : nil
                            }
                            .prefix(5)
                        print("🔍 Found these schemes in HTML instead: \(Array(Set(allSchemes)))")
                    }
                }
                
                // Load in WebView on main thread
                await MainActor.run {
                    self.pageTitle = displaytitle ?? title
                    self.loadCustomHtml(finalHtml, theme: theme)
                    
                    // Check if this page is already saved
                    self.checkIfPageIsSaved()
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
    
    /// Remove unwanted infobox sections that should be hidden by default
    /// Matches Android's preprocessHtml behavior in PageAssetDownloader.kt
    private func removeUnwantedInfoboxSections(from html: String) -> String {
        var processedHtml = html
        
        // Selectors to remove (matching Android)
        let selectorsToRemove = [
            "advanced-data",
            "leagues-global-flag",
            "infobox-padding"
        ]
        
        for selector in selectorsToRemove {
            // Pattern to match <tr> elements with the class anywhere in the class attribute
            let pattern = "<tr[^>]*?class=[\"'][^\"']*?\(selector)[^\"']*?[\"'][^>]*?>.*?</tr>"
            
            do {
                let regex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators])
                let matches = regex.matches(in: processedHtml, range: NSRange(location: 0, length: processedHtml.utf16.count))
                
                if matches.count > 0 {
                    print("🔍 ArticleViewModel: Found \(matches.count) elements with class '\(selector)' to remove")
                }
                
                // Remove matches in reverse order to maintain correct indices
                for match in matches.reversed() {
                    if let range = Range(match.range, in: processedHtml) {
                        processedHtml.removeSubrange(range)
                    }
                }
            } catch {
                print("❌ ArticleViewModel: Failed to create regex for selector '\(selector)': \(error)")
            }
        }
        
        return processedHtml
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
            // Progress updated automatically by WebKit observer
            
            // Build the final HTML document
            let finalHtml = contentLoader.buildFullHtmlDocument(
                pageContent: pageContent,
                theme: theme,
                collapseTablesEnabled: collapseTablesEnabled
            )
            
            print("🏗️ ArticleViewModel: Built custom HTML document (\(finalHtml.count) characters)")
            
            // Update page title
            pageTitle = pageContent.parseResult.displaytitle ?? pageContent.parseResult.title ?? "OSRS Wiki"
            
            // Load the custom HTML in WebView
            loadCustomHtml(finalHtml, theme: theme)
            
        case .failure(let error):
            print("❌ ArticleViewModel: Failed to load content: \(error.localizedDescription)")
            isLoading = false
            errorMessage = "Failed to load page: \(error.localizedDescription)"
        }
    }
    
    private func loadCustomHtml(_ html: String, theme: any osrsThemeProtocol = osrsLightTheme()) {
        guard let webView = webView else { return }
        
        print("🌐 ArticleViewModel: Loading custom HTML in WebView")
        print("🌐 ArticleViewModel: HTML content length: \(html.count) characters")
        
        // PRELOADING INTEGRATION: Trigger map preloading before WebView loads HTML
        // This mirrors Android's proactive preloading approach
        Task { @MainActor in
            // Set parent view for map preloading containers
            if let parentView = webView.superview {
                osrsMapPreloadService.shared.setParentView(parentView)
            }
            
            // Parse HTML for maps and start preloading
            print("🗺️ ArticleViewModel: Starting map preloading from HTML")
            osrsMapPreloadService.shared.preloadMapsFromHTML(html)
        }
        
        // Keep wiki base URL for content
        // CRITICAL FIX: Use custom scheme baseURL to avoid mixed content security blocking
        // WebKit treats custom schemes as insecure and blocks them when baseURL is HTTPS
        let customScheme = UserDefaults.standard.string(forKey: "WKURLSchemeHandler_Scheme") ?? "app-assets"
        let customBaseURL = URL(string: "\(customScheme)://localhost/")!
        print("🔧 CRITICAL FIX: Using custom scheme baseURL: \(customBaseURL) instead of HTTPS")
        print("🔧 This resolves WebKit mixed content security blocking that prevented WKURLSchemeHandler from being called")
        
        // Option B: Skip WKUserScript injection - assets loaded via WKURLSchemeHandler
        print("📱 Option B: Skipping WKUserScript injection - using WKURLSchemeHandler for asset loading")
        
        webView.loadHTMLString(html, baseURL: customBaseURL)
        
        // Apply theme colors and reveal body after loading, like Android does
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            print("🌐 ArticleViewModel: Revealing body and completing load...")
            self.revealBody(webView: webView)
            
            // Complete the loading process - maintain timing measurement but add history tracking
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.isLoading = false
                self.loadingProgress = 1.0
                self.progressCompletionTime = Date() // Record progress completion for timing measurement
                print("✅ ArticleViewModel: Loading completed!")
                
                // Track this page visit in history
                self.addToHistory()
            }
        }
    }
    
    // MARK: - History Tracking
    
    /// Add this page visit to history
    private func addToHistory() {
        // Create a history item for this page visit using metadata when available
        let historyItem = HistoryItem(
            id: UUID().uuidString,
            pageTitle: pageTitle_?.isEmpty == false ? pageTitle_! : extractTitleFromUrl(pageUrl),
            pageUrl: pageUrl,
            visitedDate: Date(),
            thumbnailUrl: thumbnailUrl_, // Use provided thumbnail from navigation metadata
            description: snippet_ // Use provided snippet from navigation metadata
        )
        
        historyRepository.addToHistory(historyItem)
        print("📚 ArticleViewModel: Added page to history: '\(historyItem.pageTitle)' with snippet='\(snippet_ ?? "nil")' thumbnail='\(thumbnailUrl_?.absoluteString ?? "nil")'")
    }
    
    private func injectBundleAssetsViaUserScript(webView: WKWebView) {
        print("🎨 ArticleViewModel: Injecting CSS/JS assets via WKUserScript")
        
        // Remove any existing user scripts to avoid duplicates
        webView.configuration.userContentController.removeAllUserScripts()
        
        // Inject CSS files
        let cssAssets = [
            "themes.css",
            "base.css", 
            "fonts.css",
            "layout.css",
            "components.css",
            "wiki-integration.css",
            "navbox_styles.css",
            "collapsible_tables.css",
            "collapsible_sections.css",
            "switch_infobox_styles.css",
            "fixes.css"
        ]
        
        // Load and inject CSS
        var combinedCSS = ""
        for cssFile in cssAssets {
            if let path = Bundle.main.path(forResource: cssFile, ofType: nil),
               let cssContent = try? String(contentsOfFile: path) {
                combinedCSS += cssContent + "\n"
                print("✅ Loaded CSS: \(cssFile)")
            } else {
                print("❌ Failed to load CSS: \(cssFile)")
            }
        }
        
        if !combinedCSS.isEmpty {
            let cssInjectionScript = """
            var style = document.createElement('style');
            style.innerHTML = `\(combinedCSS.replacingOccurrences(of: "`", with: "\\`"))`;
            document.head.appendChild(style);
            console.log('📱 iOS: Injected CSS styles via WKUserScript');
            """
            
            let cssUserScript = WKUserScript(source: cssInjectionScript, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
            webView.configuration.userContentController.addUserScript(cssUserScript)
        }
        
        // Inject JavaScript files
        let jsAssets = [
            "startup.js",
            "tablesort.min.js",
            "tablesort_init.js", 
            "collapsible_content.js",
            "table_wrapper.js",
            "infobox_switcher_bootstrap.js",
            "switch_infobox.js",
            "horizontal_scroll_interceptor.js",
            "responsive_videos.js",
            "clipboard_bridge.js"
        ]
        
        // Load and inject JavaScript
        for jsFile in jsAssets {
            if let path = Bundle.main.path(forResource: jsFile, ofType: nil),
               let jsContent = try? String(contentsOfFile: path) {
                
                let jsInjectionScript = """
                \(jsContent)
                console.log('📱 iOS: Loaded JS script: \(jsFile)');
                """
                
                let jsUserScript = WKUserScript(source: jsInjectionScript, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
                webView.configuration.userContentController.addUserScript(jsUserScript)
                print("✅ Injected JS: \(jsFile)")
            } else {
                print("❌ Failed to load JS: \(jsFile)")
            }
        }
        
        print("🎨 ArticleViewModel: Asset injection complete")
    }
    
    /// Inject theme colors into WebView (called from ArticleWebView.updateUIView)
    func injectThemeColors(_ themeManager: osrsThemeManager) {
        // Option B: Apply theme colors and final styling touches to achieve Android parity
        guard let webView = webView else { return }
        
        print("🎨 Option B: Applying theme colors and final styling for Android parity")
        applyThemeColors(webView: webView, themeManager: themeManager) {
            print("✅ Option B: Theme colors applied successfully")
            
            // Apply additional styling fixes for complete Android parity
            self.applyFinalStylingFixes(webView: webView)
        }
    }
    
    /// Apply iOS theme colors as CSS variables to match Android behavior
    private func applyThemeColors(webView: WKWebView, themeManager: osrsThemeManager, completion: @escaping () -> Void) {
        print("🎨 ArticleViewModel: Applying iOS theme colors as CSS variables")
        
        // Get current theme colors from iOS theme manager
        let currentTheme = themeManager.currentTheme
        
        // Map iOS theme colors to CSS variables (matching Android's colorSurfaceVariant etc)
        let themeColors: [String: String] = [
            "--colorsurface": currentTheme.surface.toHexString(),
            "--coloronsurface": currentTheme.onSurface.toHexString(),
            "--colorsurfacevariant": currentTheme.surfaceVariant.toHexString(),
            "--coloronsurfacevariant": currentTheme.onSurfaceVariant.toHexString(),
            "--colorprimarycontainer": currentTheme.primaryContainer.toHexString(),
            "--coloronprimarycontainer": currentTheme.onPrimaryContainer.toHexString(),
            "--coloroutline": currentTheme.outline.toHexString(),
            "--ooui-interface": currentTheme.surfaceVariant.toHexString(),
            "--ooui-interface-border": currentTheme.outline.toHexString()
        ]
        
        // Build JavaScript object string
        let jsObjectEntries = themeColors.map { key, value in
            "    '\(key)': '\(value)'"
        }.joined(separator: ",\n")
        
        // Create JavaScript to inject CSS custom properties
        let script = """
        (function() {
            try {
                console.log('📱 iOS: Starting theme color and font injection...');
                
                const themeColors = {
                \(jsObjectEntries)
                };
                
                console.log('📱 iOS: Theme colors object created:', themeColors);
                
                for (const [key, value] of Object.entries(themeColors)) {
                    document.documentElement.style.setProperty(key, value);
                }
                console.log('📱 iOS: Applied theme colors as CSS variables');
                
                // FEATURE PARITY FIX 1: Remove edit links like Android does
                console.log('📱 iOS: Removing [edit | edit source] links for Android parity');
                const editLinks = document.querySelectorAll('span.mw-editsection');
                editLinks.forEach(link => {
                    link.remove();
                });
                console.log('📱 iOS: Removed', editLinks.length, 'edit links');
                
                // FEATURE PARITY FIX 2: Apply Alegreya font to page title and headings like Android
                console.log('📱 iOS: Starting Alegreya font application...');
                
                // Test document state
                console.log('📱 iOS: Document ready state:', document.readyState);
                console.log('📱 iOS: Document body exists:', !!document.body);
                
                const pageHeader = document.querySelector('h1.page-header');
                const allHeadings = document.querySelectorAll('h1, h2, h3, h4, h5, h6');
                
                console.log('📱 iOS: Found page header:', !!pageHeader);
                console.log('📱 iOS: Found', allHeadings.length, 'headings total');
                
                // Test font availability using different methods
                console.log('📱 iOS: Testing font availability...');
                
                // Method 1: Check if font is loaded
                if (document.fonts && document.fonts.check) {
                    const alegreyaBoldLoaded = document.fonts.check('16px "Alegreya-Bold"');
                    const alegreyaLoaded = document.fonts.check('16px Alegreya');
                    console.log('📱 iOS: Alegreya-Bold loaded:', alegreyaBoldLoaded);
                    console.log('📱 iOS: Alegreya loaded:', alegreyaLoaded);
                }
                
                // Method 2: Create test element to see computed font
                const testElement = document.createElement('div');
                testElement.style.fontFamily = '"Alegreya-Bold", "Alegreya", Georgia, serif';
                testElement.style.fontSize = '16px';
                testElement.textContent = 'Test';
                testElement.style.position = 'absolute';
                testElement.style.left = '-9999px';
                document.body.appendChild(testElement);
                const computedFont = window.getComputedStyle(testElement).fontFamily;
                document.body.removeChild(testElement);
                console.log('📱 iOS: Test element computed fontFamily:', computedFont);
                
                if (pageHeader) {
                    console.log('📱 iOS: Applying font to page header...');
                    pageHeader.style.fontFamily = '"Alegreya-Bold", "Alegreya", Georgia, serif';
                    pageHeader.style.fontWeight = 'bold';
                    console.log('📱 iOS: Applied font to page header');
                    
                    // Force style recalculation
                    pageHeader.offsetHeight;
                    
                    // Check what font was actually applied
                    const appliedFont = window.getComputedStyle(pageHeader).fontFamily;
                    console.log('📱 iOS: Page header final computed fontFamily:', appliedFont);
                } else {
                    console.log('📱 iOS: No page header found');
                }
                
                console.log('📱 iOS: Processing', allHeadings.length, 'headings...');
                allHeadings.forEach((heading, index) => {
                    try {
                        const level = parseInt(heading.tagName.substring(1));
                        const fontFamily = level <= 2 ? '"Alegreya-Bold", "Alegreya", Georgia, serif' : '"Alegreya-Medium", "Alegreya", Georgia, serif';
                        const fontWeight = level <= 2 ? 'bold' : '500';
                        
                        heading.style.fontFamily = fontFamily;
                        heading.style.fontWeight = fontWeight;
                        
                        // Force style recalculation
                        heading.offsetHeight;
                        
                        // Debug first few headings
                        if (index < 3) {
                            const appliedFont = window.getComputedStyle(heading).fontFamily;
                            console.log('📱 iOS: Heading', heading.tagName, 'level', level, 'set to:', fontFamily);
                            console.log('📱 iOS: Heading', heading.tagName, 'computed fontFamily:', appliedFont);
                            console.log('📱 iOS: Heading text:', heading.textContent.substring(0, 50));
                        }
                    } catch (headingError) {
                        console.error('📱 iOS: Error processing heading', index, ':', headingError);
                    }
                });
                
                console.log('📱 iOS: ✅ Successfully applied Alegreya fonts to', allHeadings.length, 'headings');
                
                // DEBUG: Test if :has() selector is actually supported in this WebKit version
                const hasSupported = CSS.supports('selector(.test:has(.child))');
                console.log('📱 iOS WebKit :has() support:', hasSupported);
                
                // DEBUG: Check actual HTML structure
                const infoboxes = document.querySelectorAll('.infobox');
                console.log('📱 iOS: Found', infoboxes.length, 'infoboxes');
                
                console.log('📱 iOS: ✅ All styling fixes completed successfully');
                
            } catch (error) {
                console.error('📱 iOS: CRITICAL ERROR in theme/font injection:', error);
                console.error('📱 iOS: Error name:', error.name);
                console.error('📱 iOS: Error message:', error.message);
                console.error('📱 iOS: Error stack:', error.stack);
                
                // Try to continue with minimal fixes if main script fails
                try {
                    console.log('📱 iOS: Attempting fallback font application...');
                    const pageHeader = document.querySelector('h1.page-header');
                    if (pageHeader) {
                        pageHeader.style.fontFamily = 'Alegreya-Bold, Georgia, serif';
                        console.log('📱 iOS: Fallback - applied font to page header');
                    }
                } catch (fallbackError) {
                    console.error('📱 iOS: Even fallback failed:', fallbackError);
                }
            }
        })();
        """
        
        print("🎨 ArticleViewModel: Evaluating theme color injection JavaScript")
        webView.evaluateJavaScript(script) { result, error in
            if let error = error {
                print("❌ ArticleViewModel: Theme color injection failed: \(error.localizedDescription)")
            } else {
                print("✅ ArticleViewModel: Theme colors applied successfully")
            }
            completion()
        }
    }
    
    /// Apply final styling fixes for complete Android parity
    private func applyFinalStylingFixes(webView: WKWebView) {
        print("🎨 ArticleViewModel: Applying final styling fixes for Android parity")
        
        let finalStylingScript = """
        (function() {
            console.log('🎨 iOS: Applying final styling fixes for complete Android parity');
            
            // Apply colorSurfaceVariant background to collapsible containers
            const collapsibleContainers = document.querySelectorAll('.navbox, .collapsible, .mw-collapsible');
            collapsibleContainers.forEach(container => {
                container.style.backgroundColor = 'var(--colorsurfacevariant)';
                container.style.border = '1px solid var(--coloroutline)';
            });
            
            // Ensure infoboxes use the proper theme colors
            const infoboxes = document.querySelectorAll('.infobox');
            infoboxes.forEach(infobox => {
                infobox.style.backgroundColor = 'var(--colorsurfacevariant)';
                infobox.style.border = '2px solid var(--coloroutline)';
            });
            
            console.log('✅ iOS: Final styling fixes applied successfully');
        })();
        """
        
        webView.evaluateJavaScript(finalStylingScript) { result, error in
            if let error = error {
                print("❌ ArticleViewModel: Final styling fixes failed: \(error.localizedDescription)")
            } else {
                print("✅ ArticleViewModel: Final styling fixes applied successfully")
            }
        }
    }
    
    /// Build HTML with proper asset links matching Android's approach
    private func buildHtmlWithAssetLinks(originalHtml: String, theme: any osrsThemeProtocol) -> String {
        print("🔗 ArticleViewModel: Building HTML with iOS asset links")
        
        // Extract body content and title from original HTML
        let bodyContent = extractBodyContent(from: originalHtml)
        let titleContent = extractTitleContent(from: originalHtml) ?? pageTitle
        
        // Use osrsPageHtmlBuilder to generate HTML with asset links
        let htmlBuilder = osrsPageHtmlBuilder()
        var htmlWithLinks = htmlBuilder.buildFullHtmlDocument(
            title: titleContent,
            bodyContent: bodyContent,
            theme: theme,
            collapseTablesEnabled: collapseTablesEnabled,
            includeAssetLinks: true  // This generates <link> and <script> tags
        )
        
        // Replace href and src attributes to use ios-assets:// scheme
        htmlWithLinks = htmlWithLinks
            .replacingOccurrences(of: "href=\"", with: "href=\"ios-assets://localhost/")
            .replacingOccurrences(of: "src=\"", with: "src=\"ios-assets://localhost/")
        
        print("🔗 ArticleViewModel: Generated HTML with iOS asset links (\(htmlWithLinks.count) characters)")
        return htmlWithLinks
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
            "web/table_wrapper.js",
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
    
    func completeLoadingWithBodyReveal() {
        guard let webView = webView else {
            print("❌ ArticleViewModel: WebView not available for body reveal")
            return
        }
        
        let timeString = DateFormatter.timeFormatter.string(from: Date())
        let revealBodyJs = "document.body.style.visibility = 'visible';"
        print("📊 [\(timeString)] 👁️ REVEALING BODY: Making content visible to user...")
        
        webView.evaluateJavaScript(revealBodyJs) { [weak self] result, error in
            DispatchQueue.main.async {
                let completionTimeString = DateFormatter.timeFormatter.string(from: Date())
                if let error = error {
                    print("📊 [\(completionTimeString)] ❌ BODY REVEAL FAILED: \(error)")
                } else {
                    print("📊 [\(completionTimeString)] ✅ CONTENT NOW VISIBLE: Body revealed - user can see page content!")
                }
                
                // TIMELINE COMPLETION: Now that body is revealed, complete progress to 100%
                self?.loadingProgress = 1.0
                self?.loadingProgressText = "Complete!"
                self?.isLoading = false
                print("📊 [\(completionTimeString)] 🏁 PROGRESS BAR HIDDEN: Loading complete - content is now visible")
                
                // Record final page visibility time for timing measurements
                self?.pageVisibilityTime = Date()
            }
        }
    }
    
    private func revealBody(webView: WKWebView) {
        let timeString = DateFormatter.timeFormatter.string(from: Date())
        let revealBodyJs = "document.body.style.visibility = 'visible';"
        print("📊 [\(timeString)] 👁️ REVEALING BODY: Making content visible to user...")
        
        webView.evaluateJavaScript(revealBodyJs) { result, error in
            let completionTimeString = DateFormatter.timeFormatter.string(from: Date())
            if let error = error {
                print("📊 [\(completionTimeString)] ❌ BODY REVEAL FAILED: \(error)")
            } else {
                print("📊 [\(completionTimeString)] ✅ CONTENT NOW VISIBLE: Body revealed - user can see page content!")
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
    
    // JavaScript bridge methods - updated to match Android CSS variable injection
    // (Note: The injectThemeColors implementation is now at line 395)
    
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
        
        // Clean up preloaded maps when ArticleViewModel is deallocated
        Task { @MainActor in
            osrsMapPreloadService.shared.clearPreloadedMaps()
        }
        
        print("🧹 ArticleViewModel: Cleaned up and deallocated")
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
        let timeString = DateFormatter.timeFormatter.string(from: Date())
        print("📊 [\(timeString)] 🌐 WEBKIT NAVIGATION FINISHED: Basic HTML loaded")
        
        // TIMING MEASUREMENT: Record when WebView navigation completes (NOT when content is visible)
        if progressCompletionTime != nil && pageVisibilityTime == nil {
            pageVisibilityTime = Date()
            print("📊 [\(timeString)] 📄 NAVIGATION COMPLETE: WebView finished loading HTML")
            
            // Calculate and log the delay
            if let startTime = progressCompletionTime, let endTime = pageVisibilityTime {
                let delay = endTime.timeIntervalSince(startTime)
                
                // Store the measured delay for external access
                self.lastMeasuredDelay = delay
                
                print("📊 TIMING RESULT: Progress-to-page delay = \(String(format: "%.3f", delay))s")
                
                // Provide automated optimization suggestions based on measured data
                if delay > 0.5 {
                    print("🔧 OPTIMIZATION: SEVERE delay detected (\(String(format: "%.3f", delay))s). Check WebView rendering pipeline.")
                } else if delay > 0.1 {
                    print("🔧 OPTIMIZATION: MODERATE delay (\(String(format: "%.3f", delay))s). Consider optimizing progress completion logic.")
                } else {
                    print("✅ OPTIMIZATION: Timing is within acceptable range (\(String(format: "%.3f", delay))s).")
                }
            }
        }
        
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
        // CRITICAL: Allow our custom scheme for WKURLSchemeHandler
        let customScheme = UserDefaults.standard.string(forKey: "WKURLSchemeHandler_Scheme") ?? "app-assets"
        if url.scheme == customScheme {
            print("🔧 Allowing internal navigation for custom scheme: \(url.scheme ?? "nil")")
            return false // Keep internal for our custom asset scheme
        }
        
        // Open non-wiki links externally
        let wikiDomains = ["oldschool.runescape.wiki", "runescape.wiki"]
        guard let host = url.host else { return true }
        return !wikiDomains.contains(where: { host.contains($0) })
    }
    
    // MARK: - Bottom Bar Actions
    
    /// Check if current page is already saved - matches Android PageReadingListManager.observeAndRefreshSaveButtonState()
    private func checkIfPageIsSaved() {
        guard !pageTitle.isEmpty else { return }
        
        let savedPages = savedPagesRepository.getSavedPages()
        let cleanTitle = cleanPageTitle(pageTitle)
        let isAlreadySaved = savedPages.contains { savedPage in
            savedPage.url == pageUrl || savedPage.title == cleanTitle || savedPage.title == pageTitle
        }
        
        isBookmarked = isAlreadySaved
        saveState = isAlreadySaved ? .saved : .notSaved
        saveProgress = isAlreadySaved ? 1.0 : 0.0
        
        print("🔖 ArticleViewModel: Checked save status - isBookmarked: \(isBookmarked), saveState: \(saveState)")
    }
    
    /// Save/bookmark toggle action - matches Android PageReadingListManager functionality
    func performSaveAction() {
        guard saveState != .downloading else { return }
        
        print("🔖 ArticleViewModel: Save action triggered - current state: \(saveState), bookmarked: \(isBookmarked)")
        
        if isBookmarked {
            // Remove from saved pages - matches Android unsaving logic
            saveState = .downloading
            saveProgress = 0.0
            
            Task {
                do {
                    // Find and remove the saved page
                    let savedPages = savedPagesRepository.getSavedPages()
                    if let savedPage = savedPages.first(where: { $0.url == pageUrl || $0.title == pageTitle }) {
                        // Show progress while removing
                        for progress in stride(from: 0.0, through: 1.0, by: 0.2) {
                            await MainActor.run {
                                self.saveProgress = progress
                            }
                            try await Task.sleep(nanoseconds: 50_000_000) // 0.05 second
                        }
                        
                        // Remove from repository
                        savedPagesRepository.removeSavedPage(savedPage.id)
                        
                        await MainActor.run {
                            self.isBookmarked = false
                            self.saveState = .notSaved
                            self.saveProgress = 0.0
                            print("✅ ArticleViewModel: Successfully removed page from saved pages")
                        }
                    } else {
                        await MainActor.run {
                            self.saveState = .error
                            print("❌ ArticleViewModel: Could not find saved page to remove")
                        }
                    }
                } catch {
                    await MainActor.run {
                        self.saveState = .error
                        print("❌ ArticleViewModel: Error removing saved page: \(error)")
                    }
                }
            }
        } else {
            // Save for offline reading - matches Android saving logic
            saveState = .downloading
            saveProgress = 0.0
            
            Task {
                do {
                    print("🔄 ArticleViewModel: Starting page save process...")
                    
                    // Step 1: Fetch page metadata from API
                    await MainActor.run { self.saveProgress = 0.1 }
                    
                    let metadata = await fetchPageMetadata()
                    
                    // Step 2: Create SavedPage object with proper metadata
                    await MainActor.run { self.saveProgress = 0.2 }
                    
                    let savedPage = SavedPage(
                        id: UUID().uuidString,
                        title: cleanPageTitle(pageTitle),
                        description: metadata.description ?? extractPageDescription(),
                        url: pageUrl,
                        thumbnailUrl: metadata.thumbnailUrl ?? extractThumbnailUrl(),
                        savedDate: Date(),
                        isOfflineAvailable: false // TODO: Implement offline content storage
                    )
                    
                    // Step 3: Save page metadata to repository
                    await MainActor.run { self.saveProgress = 0.3 }
                    
                    savedPagesRepository.addSavedPage(savedPage)
                    print("📱 ArticleViewModel: Added page metadata to repository")
                    
                    // Step 4: Download and cache page content (simulate like Android SavedPageSyncWorker)
                    await MainActor.run { self.saveProgress = 0.5 }
                    
                    // TODO: Implement actual content downloading like Android's SavedPageSyncWorker
                    // For now, simulate the download progress
                    for progress in stride(from: 0.5, through: 0.9, by: 0.1) {
                        await MainActor.run {
                            self.saveProgress = progress
                        }
                        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
                    }
                    
                    // Step 5: Complete save process
                    await MainActor.run {
                        self.isBookmarked = true
                        self.saveState = .saved
                        self.saveProgress = 1.0
                        print("✅ ArticleViewModel: Successfully saved page")
                    }
                    
                } catch {
                    await MainActor.run {
                        self.saveState = .error
                        self.saveProgress = 0.0
                        print("❌ ArticleViewModel: Error saving page: \(error)")
                    }
                }
            }
        }
    }
    
    /// Clean page title by removing HTML tags - matches Android title cleaning
    private func cleanPageTitle(_ title: String) -> String {
        // Remove HTML tags like <span class="mw-page-title-main">Varrock</span>
        let cleanTitle = title.replacingOccurrences(of: #"<[^>]*>"#, with: "", options: .regularExpression)
        return cleanTitle.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Fetch page metadata from MediaWiki API - matches Android metadata extraction
    private func fetchPageMetadata() async -> (description: String?, thumbnailUrl: URL?) {
        let cleanTitle = cleanPageTitle(pageTitle)
        
        // Build MediaWiki API URL to get page info and images
        var components = URLComponents(string: "https://oldschool.runescape.wiki/api.php")!
        components.queryItems = [
            URLQueryItem(name: "action", value: "query"),
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "formatversion", value: "2"),
            URLQueryItem(name: "titles", value: cleanTitle),
            URLQueryItem(name: "prop", value: "extracts|pageimages"),
            URLQueryItem(name: "exintro", value: "1"), // Only intro section
            URLQueryItem(name: "explaintext", value: "1"), // Plain text, not HTML
            URLQueryItem(name: "exsectionformat", value: "plain"),
            URLQueryItem(name: "exchars", value: "200"), // Limit to 200 characters
            URLQueryItem(name: "piprop", value: "thumbnail"),
            URLQueryItem(name: "pithumbsize", value: "200") // 200px thumbnail
        ]
        
        guard let url = components.url else {
            print("❌ ArticleViewModel: Failed to build metadata API URL")
            return (nil, nil)
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let query = json["query"] as? [String: Any],
               let pages = query["pages"] as? [[String: Any]],
               let page = pages.first {
                
                // Extract description
                let description = page["extract"] as? String
                
                // Extract thumbnail URL
                var thumbnailUrl: URL?
                if let thumbnail = page["thumbnail"] as? [String: Any],
                   let thumbnailSource = thumbnail["source"] as? String {
                    thumbnailUrl = URL(string: thumbnailSource)
                }
                
                print("📱 ArticleViewModel: Fetched metadata - description: \(description?.prefix(50) ?? "nil"), thumbnail: \(thumbnailUrl?.absoluteString ?? "nil")")
                
                return (description, thumbnailUrl)
            }
        } catch {
            print("❌ ArticleViewModel: Error fetching page metadata: \(error)")
        }
        
        return (nil, nil)
    }
    
    /// Extract page description from current content - matches Android getSnippet() functionality
    private func extractPageDescription() -> String? {
        // Fallback description if metadata fetch fails
        return "OSRS Wiki article: \(cleanPageTitle(pageTitle))"
    }
    
    /// Extract thumbnail URL from current content - matches Android getThumbnailUrl() functionality  
    private func extractThumbnailUrl() -> URL? {
        // Fallback - will be replaced by API metadata
        return nil
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
        webView.evaluateJavaScript(expandScript) { [weak self] (_, error) in
            if let error = error {
                print("🚨 ArticleViewModel: Error expanding collapsible content: \(error)")
            }
            
            // After expanding content, present the native find interface
            DispatchQueue.main.async {
                self?.presentNativeFindInterface()
            }
        }
        
        print("🔍 ArticleViewModel: Find in page requested - expanding collapsible content")
    }
    
    /// Present native iOS find interface using UIFindInteraction (iOS 16+)
    private func presentNativeFindInterface() {
        guard let webView = webView else { return }
        
        if #available(iOS 16.0, *) {
            // Use native UIFindInteraction for iOS 16+
            webView.findInteraction?.presentFindNavigator(showingReplace: false)
            print("🔍 ArticleViewModel: Presented native find interface (iOS 16+)")
        } else {
            // Fallback for iOS 14-15: Use basic findString API
            // Note: This requires user input, so we'd need a custom UI
            print("🔍 ArticleViewModel: iOS 16+ required for full find interface. Consider implementing custom UI for older iOS versions.")
        }
    }
    
    /// Appearance/theme action - matches Android AppearanceSettingsActivity
    func performAppearanceAction() {
        // Navigate to appearance settings by sending notification
        // This matches Android's behavior of launching AppearanceSettingsActivity
        NotificationCenter.default.post(name: .showAppearanceSettings, object: nil)
        print("🎨 ArticleViewModel: Navigating to appearance settings")
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