//
//  osrsPageHtmlBuilder.swift
//  OSRS Wiki
//
//  Created on article rendering parity session
//

import Foundation
import UIKit

class osrsPageHtmlBuilder {
    private let logTag = "PageLoadTrace"
    
    // App-specific stylesheets (matching Android implementation)
    private let styleSheetAssets = [
        "styles/themes.css",
        "styles/base.css", 
        "styles/fonts.css",
        "styles/layout.css",
        "styles/components.css",
        "styles/wiki-integration.css",
        "styles/navbox_styles.css",
        "styles/collapsible_tables.css",
        "web/collapsible_sections.css",
        "web/switch_infobox_styles.css",
        "styles/fixes.css"
    ]
    
    // MediaWiki ResourceLoader artifacts
    private let mediawikiArtifacts = [
        "startup.js"
    ]
    
    // Base JavaScript assets
    private let jsAssetPaths = [
        "web/map_bridge.js",  // CRITICAL: Load bridge first before other scripts need it
        "js/tablesort.min.js",
        "js/tablesort_init.js", 
        "web/collapsible_content.js",
        "web/infobox_switcher_bootstrap.js",
        "web/switch_infobox.js",
        "web/horizontal_scroll_interceptor.js",
        "web/responsive_videos.js",
        "web/clipboard_bridge.js"
    ]
    
    private func createThemeUtilityScript() -> String {
        return """
        <script>
            // Theme switching utility for instant theme changes
            window.OSRSWikiTheme = {
                switchTheme: function(isDark) {
                    var body = document.body;
                    if (!body) return;
                    
                    // Remove existing theme classes
                    body.classList.remove('theme-osrs-dark');
                    
                    // Add dark theme class if needed
                    if (isDark) {
                        body.classList.add('theme-osrs-dark');
                    }
                    
                    // Force immediate style recalculation
                    body.offsetHeight;
                    
                    // Ensure page remains visible after theme change
                    if (body.style.visibility !== 'visible') {
                        body.style.visibility = 'visible';
                    }
                }
            };
        </script>
        """
    }
    
    private func createTableCollapseScript(collapseTablesEnabled: Bool) -> String {
        return """
        <script>
            // Global variable for table collapse preference that collapsible_content.js can read
            window.OSRS_TABLE_COLLAPSED = \(collapseTablesEnabled ? "true" : "false");
            console.log('osrsPageHtmlBuilder: Set global collapse preference to ' + window.OSRS_TABLE_COLLAPSED);
        </script>
        """
    }
    
    private func generateMediaWikiVariables(title: String, bodyContent: String) -> String {
        // Generate smart RLPAGEMODULES based on content analysis
        let detectedModules = osrsWikiModuleRegistry.generateRLPAGEMODULES(bodyContent: bodyContent, title: title)
        let modulesList = detectedModules.map { "\"\($0)\"" }.joined(separator: ", ")
        
        // Use page title for MediaWiki variables  
        let safeTitle = title.replacingOccurrences(of: "\"", with: "\\\"")
        
        return """
        <script>
            // Smart MediaWiki variables generated based on page content
            // Module detection via osrsWikiModuleRegistry for scalable maintenance
            var RLCONF = {"wgBreakFrames": false, "wgSeparatorTransformTable": ["", ""], "wgDigitTransformTable": ["", ""], "wgDefaultDateFormat": "dmy", "wgMonthNames": ["", "January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"], "wgRequestId": "smart-module-loader", "wgCanonicalNamespace": "", "wgCanonicalSpecialPageName": false, "wgNamespaceNumber": 0, "wgPageName": "\(safeTitle)", "wgTitle": "\(safeTitle)", "wgCurRevisionId": 0, "wgRevisionId": 0, "wgArticleId": 1, "wgIsArticle": true, "wgIsRedirect": false, "wgAction": "view", "wgUserName": null, "wgUserGroups": ["*"], "wgPageViewLanguage": "en-gb", "wgPageContentLanguage": "en-gb", "wgPageContentModel": "wikitext", "wgRelevantPageName": "\(safeTitle)", "wgRelevantArticleId": 1, "wgIsProbablyEditable": true, "wgRelevantPageIsProbablyEditable": true, "wgRestrictionEdit": [], "wgRestrictionMove": [], "wgServer": "https://oldschool.runescape.wiki", "wgServerName": "oldschool.runescape.wiki", "wgScriptPath": "", "wgScript": "/load.php"};
            var RLSTATE = {"ext.gadget.switch-infobox-styles": "ready", "ext.gadget.articlefeedback-styles": "ready", "ext.gadget.falseSubpage": "ready", "ext.gadget.headerTargetHighlight": "ready", "site.styles": "ready", "user.styles": "ready", "user": "ready", "user.options": "loading", "ext.cite.styles": "ready", "ext.kartographer.style": "ready", "skins.minerva.base.styles": "ready", "skins.minerva.content.styles.images": "ready", "mediawiki.hlist": "ready", "skins.minerva.codex.styles": "ready", "skins.minerva.icons.wikimedia": "ready", "skins.minerva.mainMenu.icons": "ready", "skins.minerva.mainMenu.styles": "ready", "jquery.tablesorter.styles": "ready", "ext.embedVideo.styles": "ready", "mobile.init.styles": "ready"};
            var RLPAGEMODULES = [\(modulesList)];
            
            // Log detected modules for debugging
            console.log('osrsWikiModuleRegistry detected modules for "\(safeTitle)":', RLPAGEMODULES);
        </script>
        """
    }
    
    private func createInlineMapBridge() -> String {
        return """
        <script>
        // CRITICAL: Inline Map Bridge for iOS MapLibre integration
        // This ensures the bridge is available as early as possible
        (function() {
            console.log('🚨 [INLINE-BRIDGE] Inline map bridge executing...');
            console.log('🚨 [INLINE-BRIDGE] Document ready state:', document.readyState);
            
            if (window.OsrsWikiBridge) {
                console.log('🚨 [INLINE-BRIDGE] Bridge already exists, skipping...');
                return;
            }
            
            // Create OsrsWikiBridge equivalent for iOS MapLibre integration
            window.OsrsWikiBridge = {
                onMapPlaceholderMeasured: function(id, rectJson, mapDataJson) {
                    console.log('🚨 [INLINE-BRIDGE] onMapPlaceholderMeasured called:', id);
                    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.mapBridge) {
                        window.webkit.messageHandlers.mapBridge.postMessage({
                            action: 'onMapPlaceholderMeasured',
                            id: id,
                            rectJson: rectJson,
                            mapDataJson: mapDataJson
                        });
                        console.log('🚨 [INLINE-BRIDGE] Message sent to native layer');
                    } else {
                        console.error('🚨 [INLINE-BRIDGE] webkit.messageHandlers.mapBridge not available');
                    }
                },
                
                onCollapsibleToggled: function(mapId, isOpening) {
                    console.log('🚨 [INLINE-BRIDGE] onCollapsibleToggled called:', mapId, isOpening);
                    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.mapBridge) {
                        window.webkit.messageHandlers.mapBridge.postMessage({
                            action: 'onCollapsibleToggled',
                            mapId: mapId,
                            isOpening: isOpening
                        });
                    } else {
                        console.error('🚨 [INLINE-BRIDGE] webkit.messageHandlers.mapBridge not available');
                    }
                },
                
                setHorizontalScroll: function(inProgress) {
                    console.log('🚨 [INLINE-BRIDGE] setHorizontalScroll called:', inProgress);
                    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.mapBridge) {
                        window.webkit.messageHandlers.mapBridge.postMessage({
                            action: 'setHorizontalScroll',
                            inProgress: inProgress
                        });
                    } else {
                        console.error('🚨 [INLINE-BRIDGE] webkit.messageHandlers.mapBridge not available');
                    }
                },
                
                log: function(message) {
                    console.log('🚨 [INLINE-BRIDGE] log called:', message);
                    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.mapBridge) {
                        window.webkit.messageHandlers.mapBridge.postMessage({
                            action: 'log',
                            message: message
                        });
                    } else {
                        console.error('🚨 [INLINE-BRIDGE] webkit.messageHandlers.mapBridge not available');
                    }
                }
            };
            
            console.log('🗺️ iOS OsrsWikiBridge initialized and ready');
            console.log('🚨 [INLINE-BRIDGE] Bridge object created:', typeof window.OsrsWikiBridge);
            
            // Test the bridge immediately if possible
            if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.mapBridge) {
                console.log('🚨 [INLINE-BRIDGE] Testing bridge connection...');
                window.OsrsWikiBridge.log('Inline bridge initialization test message');
            } else {
                console.log('🚨 [INLINE-BRIDGE] Bridge created but message handlers not yet available');
            }
        })();
        </script>
        """
    }
    
    func buildFullHtmlDocument(title: String, bodyContent: String, theme: any osrsThemeProtocol, collapseTablesEnabled: Bool = true, includeAssetLinks: Bool = false) -> String {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Clean title and prepare header
        let cleanedTitle = extractMainTitle(title)
        let documentTitle = cleanedTitle.isEmpty ? "OSRS Wiki" : cleanedTitle
        let titleHeaderHtml = "<h1 class=\"page-header\">\(documentTitle)</h1>"
        
        // Clean any existing page-header titles from bodyContent to prevent duplication
        let cleanedBodyContent = removeDuplicatePageHeaders(bodyContent)
        let finalBodyContent = titleHeaderHtml + cleanedBodyContent
        
        let themeClass = (theme is osrsDarkTheme) ? "theme-osrs-dark" : ""
        
        // Detect presence of GE price charts in the content and include widget script when needed
        let needsGECharts = cleanedBodyContent.contains("GEChartBox") ||
                           cleanedBodyContent.contains("GEdatachart") ||
                           cleanedBodyContent.contains("GEdataprices")
        
        if needsGECharts {
            print("\(logTag): Detected GE chart markers in content; will include highcharts widget script.")
        }
        
        // Generate CSS links only if requested (disabled for WKUserScript injection)
        let cssLinks: String
        if includeAssetLinks {
            // Get the dynamic scheme name from UserDefaults
            let customScheme = UserDefaults.standard.string(forKey: "WKURLSchemeHandler_Scheme") ?? "app-assets"
            print("\(logTag): 🔍 UserDefaults WKURLSchemeHandler_Scheme = '\(UserDefaults.standard.string(forKey: "WKURLSchemeHandler_Scheme") ?? "nil")'")
            print("\(logTag): 🔍 Using scheme: '\(customScheme)'")
            
            cssLinks = styleSheetAssets.map { assetPath in
                // Option B: Generate custom scheme URLs for WKURLSchemeHandler
                return "<link rel=\"stylesheet\" href=\"\(customScheme)://localhost/\(assetPath)\">"
            }.joined(separator: "\n")
            print("\(logTag): Including CSS asset links with \(customScheme):// URLs for Option B")
            print("\(logTag): 📋 First CSS link: \(cssLinks.components(separatedBy: "\n").first ?? "none")")
        } else {
            cssLinks = "<!-- CSS assets injected via WKUserScript -->"
            print("\(logTag): Skipping CSS links - using WKUserScript injection")
        }
        
        // Generate MediaWiki scripts only if requested
        let mediawikiScripts: String
        if includeAssetLinks {
            let customScheme = UserDefaults.standard.string(forKey: "WKURLSchemeHandler_Scheme") ?? "app-assets"
            mediawikiScripts = mediawikiArtifacts.map { assetPath in
                // Option B: Generate custom scheme URLs for WKURLSchemeHandler
                return "<script src=\"\(customScheme)://localhost/\(assetPath)\"></script>"
            }.joined(separator: "\n")
        } else {
            mediawikiScripts = "<!-- MediaWiki scripts injected via WKUserScript -->"
        }
        
        // Build the JS list, conditionally appending the GE charts widget
        var dynamicJsAssets = jsAssetPaths
        if needsGECharts {
            dynamicJsAssets.append(contentsOf: [
                "web/highcharts-stock.js",
                "web/ge_charts_init.js"
            ])
        }
        
        let jsScripts: String
        if includeAssetLinks {
            let customScheme = UserDefaults.standard.string(forKey: "WKURLSchemeHandler_Scheme") ?? "app-assets"
            jsScripts = dynamicJsAssets.map { assetPath in
                // Option B: Generate custom scheme URLs for WKURLSchemeHandler
                return "<script src=\"\(customScheme)://localhost/\(assetPath)\"></script>"
            }.joined(separator: "\n")
        } else {
            jsScripts = "<!-- JS assets injected via WKUserScript -->"
        }
        
        // Generate smart MediaWiki variables
        let smartMediawikiVariables = generateMediaWikiVariables(title: cleanedTitle, bodyContent: cleanedBodyContent)
        
        // Create table collapse preference script
        let tableCollapseScript = createTableCollapseScript(collapseTablesEnabled: collapseTablesEnabled)
        
        // Preload the main web font to improve rendering performance
        let fontPreloadLink: String
        if includeAssetLinks {
            let customScheme = UserDefaults.standard.string(forKey: "WKURLSchemeHandler_Scheme") ?? "app-assets"
            fontPreloadLink = "<link rel=\"preload\" href=\"\(customScheme)://localhost/fonts/runescape_plain.ttf\" as=\"font\" type=\"font/ttf\" crossorigin=\"anonymous\">"
        } else {
            fontPreloadLink = "<!-- Font preload handled by injected CSS -->"
        }
        
        // Build final HTML document
        let finalHtml = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>\(documentTitle)</title>
            \(fontPreloadLink)
            \(cssLinks)
            \(createThemeUtilityScript())
            \(tableCollapseScript)
            \(smartMediawikiVariables)
        </head>
        <body class="\(themeClass)" style="visibility: hidden;">
            \(finalBodyContent)
            \(mediawikiScripts)
            \(jsScripts)
        </body>
        </html>
        """
        
        let elapsedTime = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        print("\(logTag): buildFullHtmlDocument() took \(Int(elapsedTime))ms")
        
        return finalHtml
    }
    
    /// Get a proper bundle URL for an asset (CSS/JS) that can be loaded by WKWebView
    private func getBundleAssetURL(for assetPath: String) -> URL? {
        // The assets are stored in the bundle under "Assets/" directory
        // e.g., "styles/themes.css" -> "Assets/styles/themes.css"
        let bundleAssetPath = "Assets/\(assetPath)"
        
        // Try to get the bundle URL for the asset
        if let path = Bundle.main.path(forResource: bundleAssetPath, ofType: nil) {
            return URL(fileURLWithPath: path)
        }
        
        // If that doesn't work, try without the Assets prefix (for backward compatibility)
        if let path = Bundle.main.path(forResource: assetPath, ofType: nil) {
            return URL(fileURLWithPath: path)
        }
        
        print("\(logTag): Could not find asset in bundle: \(assetPath)")
        return nil
    }
    
    /// Get a proper bundle URL for a font file that can be loaded by WKWebView
    private func getBundleFontURL(for fontName: String) -> URL? {
        // Fonts are stored in the bundle under "Font/" directory
        if let path = Bundle.main.path(forResource: fontName, ofType: nil, inDirectory: "Font") {
            return URL(fileURLWithPath: path)
        }
        
        print("\(logTag): Could not find font in bundle: \(fontName)")
        return nil
    }
    
    private func extractMainTitle(_ title: String) -> String {
        // Simple title extraction (can be enhanced later)
        return title.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func removeDuplicatePageHeaders(_ htmlContent: String) -> String {
        do {
            // Use regex to remove h1 elements with class="page-header"
            let regex = try NSRegularExpression(pattern: "<h1\\s+class=\"page-header\"[^>]*>.*?</h1>", options: [.dotMatchesLineSeparators])
            let range = NSRange(location: 0, length: htmlContent.utf16.count)
            return regex.stringByReplacingMatches(in: htmlContent, options: [], range: range, withTemplate: "")
        } catch {
            print("\(logTag): Error removing duplicate page headers: \(error)")
            return htmlContent
        }
    }
}