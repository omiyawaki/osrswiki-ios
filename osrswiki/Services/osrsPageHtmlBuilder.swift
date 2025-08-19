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
        "styles/infobox_switcher.css",
        "styles/fixes.css"
    ]
    
    // MediaWiki ResourceLoader artifacts
    private let mediawikiArtifacts = [
        "startup.js"
    ]
    
    // Base JavaScript assets
    private let jsAssetPaths = [
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
    
    func buildFullHtmlDocument(title: String, bodyContent: String, theme: any osrsThemeProtocol, collapseTablesEnabled: Bool = true) -> String {
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
        
        // Generate CSS links
        let cssLinks = styleSheetAssets.map { assetPath in
            "<link rel=\"stylesheet\" href=\"\(assetPath)\">"
        }.joined(separator: "\n")
        
        print("\(logTag): Using natural MediaWiki ResourceLoader with asset bundle loading")
        
        // Generate MediaWiki scripts
        let mediawikiScripts = mediawikiArtifacts.map { assetPath in
            "<script src=\"\(assetPath)\"></script>"
        }.joined(separator: "\n")
        
        // Build the JS list, conditionally appending the GE charts widget
        var dynamicJsAssets = jsAssetPaths
        if needsGECharts {
            dynamicJsAssets.append(contentsOf: [
                "web/highcharts-stock.js",
                "web/ge_charts_init.js"
            ])
        }
        
        let jsScripts = dynamicJsAssets.map { assetPath in
            "<script src=\"\(assetPath)\"></script>"
        }.joined(separator: "\n")
        
        // Generate smart MediaWiki variables
        let smartMediawikiVariables = generateMediaWikiVariables(title: cleanedTitle, bodyContent: cleanedBodyContent)
        
        // Create table collapse preference script
        let tableCollapseScript = createTableCollapseScript(collapseTablesEnabled: collapseTablesEnabled)
        
        // Preload the main web font to improve rendering performance
        let fontPreloadLink = "<link rel=\"preload\" href=\"runescape_plain.ttf\" as=\"font\" type=\"font/ttf\" crossorigin=\"anonymous\">"
        
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