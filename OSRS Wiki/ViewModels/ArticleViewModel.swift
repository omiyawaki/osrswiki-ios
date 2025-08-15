//
//  ArticleViewModel.swift
//  OSRS Wiki
//
//  Created on iOS webviewer implementation session
//

import SwiftUI
import WebKit
import Combine

@MainActor
class ArticleViewModel: NSObject, ObservableObject {
    @Published var isLoading: Bool = false
    @Published var loadingProgress: Double = 0.0
    @Published var errorMessage: String?
    @Published var pageTitle: String = ""
    @Published var isBookmarked: Bool = false
    @Published var hasTableOfContents: Bool = false
    @Published var tableOfContents: [TableOfContentsSection] = []
    
    let pageUrl: URL
    weak var webView: WKWebView?
    private var cancellables = Set<AnyCancellable>()
    private var progressObserver: NSKeyValueObservation?
    
    init(pageUrl: URL) {
        self.pageUrl = pageUrl
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
    
    func loadArticle() {
        guard let webView = webView else { 
            print("❌ ArticleViewModel: WebView not set")
            return 
        }
        
        isLoading = true
        errorMessage = nil
        
        print("🔗 ArticleViewModel: Loading URL: \(pageUrl.absoluteString)")
        let request = URLRequest(url: pageUrl)
        webView.load(request)
    }
    
    func reloadArticle() {
        webView?.reload()
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
    func injectThemeColors(_ theme: AppTheme) {
        let themeScript = """
            document.documentElement.style.setProperty('--color-surface', '\(theme.surfaceColor)');
            document.documentElement.style.setProperty('--color-on-surface', '\(theme.onSurfaceColor)');
            document.documentElement.style.setProperty('--color-primary', '\(theme.primaryColorHex)');
            document.documentElement.style.setProperty('--color-background', '\(theme.backgroundColorHex)');
        """
        webView?.evaluateJavaScript(themeScript)
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
        print("✅ ArticleViewModel: Finished loading")
        isLoading = false
        
        // Extract page title
        webView.evaluateJavaScript("document.title") { [weak self] result, _ in
            if let title = result as? String {
                DispatchQueue.main.async {
                    self?.pageTitle = title
                }
            }
        }
        
        // Extract table of contents
        extractTableOfContents()
        
        // Apply theme if needed
        // TODO: Get current theme from app state and inject
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
}

// MARK: - Data Models
struct TableOfContentsSection: Codable, Identifiable {
    let id: String
    let title: String
    let level: Int
}