//
//  ArticleWebView.swift
//  OSRS Wiki
//
//  Created on iOS webviewer implementation session
//

import SwiftUI
import WebKit
import UniformTypeIdentifiers

// MARK: - iOS Asset Handler (matches Android's appassets.androidplatform.net)
class IOSAssetHandler: NSObject, WKURLSchemeHandler {
    
    // MARK: - Task State Management (Fix for "This task has already been stopped" crash)
    // Using Set with ObjectIdentifier for iOS 18+ compatibility instead of NSHashTable
    private var activeTasks: Set<ObjectIdentifier> = []
    private let taskQueue = DispatchQueue(label: "IOSAssetHandler.TaskQueue", qos: .userInitiated)
    private let tasksLock = NSLock() // Thread safety for task tracking
    
    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        taskQueue.async {
            // Add task to active set to track its lifecycle
            let taskId = ObjectIdentifier(urlSchemeTask)
            self.tasksLock.lock()
            self.activeTasks.insert(taskId)
            self.tasksLock.unlock()
            
            print("🚨 IOSAssetHandler: CALLED! URL: \(urlSchemeTask.request.url?.absoluteString ?? "nil")")
            
            guard let url = urlSchemeTask.request.url else {
                print("❌ IOSAssetHandler: No URL in request")
                self.completeTask(urlSchemeTask, withError: NSError(domain: "IOSAssetHandler", code: 400, userInfo: nil))
                return
            }
            
            // Get the registered scheme from UserDefaults
            let expectedScheme = UserDefaults.standard.string(forKey: "WKURLSchemeHandler_Scheme") ?? "app-assets"
            
            guard url.scheme == expectedScheme else {
                print("❌ IOSAssetHandler: Invalid scheme: '\(url.scheme ?? "nil")' (expected: '\(expectedScheme)')")
                self.completeTask(urlSchemeTask, withError: NSError(domain: "IOSAssetHandler", code: 404, userInfo: nil))
                return
            }
        
        // Extract asset path (e.g., app-assets://localhost/styles/themes.css -> styles/themes.css)
        let assetPath = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        print("📁 IOSAssetHandler: Extracted asset path: '\(assetPath)'")
        
            // Check if this is an image request (external resource that needs proxying)
            if assetPath.hasPrefix("images/") || assetPath.contains(".png") || assetPath.contains(".jpg") || assetPath.contains(".jpeg") || assetPath.contains(".gif") || assetPath.contains(".svg") {
                print("🖼️ IOSAssetHandler: Image request detected, proxying to wiki: \(assetPath)")
                self.handleImageProxy(urlSchemeTask: urlSchemeTask, assetPath: assetPath)
                return
            }
            
            // Handle PHP/MediaWiki loader requests (external resources)
            if assetPath.hasSuffix(".php") || assetPath.contains("load.php") {
                print("🔧 IOSAssetHandler: MediaWiki loader request, proxying to wiki: \(assetPath)")
                self.handleMediaWikiProxy(urlSchemeTask: urlSchemeTask, assetPath: assetPath)
                return
            }
        
        // Debug: Show bundle structure for asset resolution debugging
        let bundleMainPath = Bundle.main.bundlePath
        print("📦 Bundle path: \(bundleMainPath)")
        if let contents = try? FileManager.default.contentsOfDirectory(atPath: bundleMainPath) {
            print("📦 Bundle root contents: \(contents.prefix(10))")
        }
        
        // Check if Assets directory exists in bundle
        let assetsDir = bundleMainPath + "/Assets"
        if FileManager.default.fileExists(atPath: assetsDir) {
            print("📦 Assets directory exists: \(assetsDir)")
            if let assetContents = try? FileManager.default.contentsOfDirectory(atPath: assetsDir) {
                print("📦 Assets/ contents: \(assetContents.prefix(10))")
                
                // Check web/ subdirectory specifically
                let webDir = assetsDir + "/web"
                if FileManager.default.fileExists(atPath: webDir) {
                    if let webContents = try? FileManager.default.contentsOfDirectory(atPath: webDir) {
                        print("📦 Assets/web/ contents: \(webContents.prefix(10))")
                    }
                } else {
                    print("📦 Assets/web/ does NOT exist in bundle")
                }
            }
        } else {
            print("📦 Assets directory does NOT exist in bundle")
        }
        
        // Try multiple path patterns to find the asset
        var bundlePath: String?
        var attemptedPaths: [String] = []
        
        print("🟡 [ASSET_HANDLER] Request for: \(assetPath)")
        
        // Pattern 1: Try direct path in Assets/ directory structure (our organized shared assets)
        let assetsPath = "Assets/\(assetPath)"
        if let path = Bundle.main.path(forResource: assetsPath, ofType: nil) {
            bundlePath = path
            print("🟢 [ASSET_HANDLER] Found via Assets/ structure: \(assetsPath)")
        } else {
            attemptedPaths.append("Bundle.main.path(forResource: '\(assetsPath)', ofType: nil)")
            print("🔍 [ASSET_HANDLER] Pattern 1 failed for: \(assetsPath)")
            
            // Additional debugging: Try different approaches for JS files specifically
            if assetPath == "web/map_bridge.js" {
                print("🔍 [DEBUG] Special debugging for map_bridge.js:")
                
                // Try various permutations
                let variations = [
                    "Assets/web/map_bridge.js",
                    "web/map_bridge",
                    "Assets/web/map_bridge", 
                    "map_bridge.js",
                    "map_bridge"
                ]
                
                for variation in variations {
                    if let path = Bundle.main.path(forResource: variation, ofType: nil) {
                        print("🔍 [DEBUG] Found \(variation) -> \(path)")
                    } else if let path = Bundle.main.path(forResource: variation, ofType: "js") {
                        print("🔍 [DEBUG] Found \(variation).js -> \(path)")
                    } else {
                        print("🔍 [DEBUG] NOT found: \(variation) (neither .js nor no extension)")
                    }
                }
            }
        }
        
        // Pattern 2: Try with extension separation in Assets/ directory
        if bundlePath == nil {
            let filename = assetPath.components(separatedBy: "/").last ?? assetPath
            let pathComponents = filename.split(separator: ".")
            if pathComponents.count >= 2,
               let lastComponent = pathComponents.last {
                let nameWithoutExtension = String(pathComponents.dropLast().joined(separator: "."))
                let fileExtension = String(lastComponent)
                let assetsFilePath = "Assets/\(assetPath.replacingOccurrences(of: filename, with: ""))\(nameWithoutExtension)"
                
                if let path = Bundle.main.path(forResource: assetsFilePath, ofType: fileExtension) {
                    bundlePath = path
                    print("🟢 [ASSET_HANDLER] Found via Assets/ + extension: \(assetsFilePath).\(fileExtension)")
                } else {
                    attemptedPaths.append("Bundle.main.path(forResource: '\(assetsFilePath)', ofType: '\(fileExtension)')")
                    print("🔍 [ASSET_HANDLER] Pattern 2 failed for: \(assetsFilePath).\(fileExtension)")
                }
            }
        }
        
        // Pattern 3: Special handling for fonts in Font/ subdirectory (legacy fonts)
        if bundlePath == nil && assetPath.hasPrefix("fonts/") {
            let fontFileName = assetPath.replacingOccurrences(of: "fonts/", with: "")
            if let path = Bundle.main.path(forResource: fontFileName, ofType: nil, inDirectory: "Font") {
                bundlePath = path
                print("✅ IOSAssetHandler: Found font in Font/ subdirectory: \(fontFileName)")
            } else {
                attemptedPaths.append("Bundle.main.path(forResource: '\(fontFileName)', ofType: nil, inDirectory: 'Font')")
            }
        }
        
        // Pattern 4: Fallback to flat bundle structure (iOS flattens some assets to bundle root)
        if bundlePath == nil {
            let flatFileName = assetPath.components(separatedBy: "/").last ?? assetPath
            if let path = Bundle.main.path(forResource: flatFileName, ofType: nil) {
                bundlePath = path
                print("🟢 [ASSET_HANDLER] Found via flat bundle: \(flatFileName)")
            } else {
                attemptedPaths.append("Bundle.main.path(forResource: '\(flatFileName)', ofType: nil)")
            }
        }
        
        // Pattern 5: Try parsing file extension from flat filename
        if bundlePath == nil {
            let flatFileName = assetPath.components(separatedBy: "/").last ?? assetPath
            let pathComponents = flatFileName.split(separator: ".")
            if pathComponents.count >= 2,
               let lastComponent = pathComponents.last {
                let nameWithoutExtension = String(pathComponents.dropLast().joined(separator: "."))
                let fileExtension = String(lastComponent)
                
                if let path = Bundle.main.path(forResource: nameWithoutExtension, ofType: fileExtension) {
                    bundlePath = path
                    print("✅ IOSAssetHandler: Found via flat + extension parsing: \(nameWithoutExtension).\(fileExtension)")
                } else {
                    attemptedPaths.append("Bundle.main.path(forResource: '\(nameWithoutExtension)', ofType: '\(fileExtension)')")
                }
            }
        }
        
            guard let finalBundlePath = bundlePath,
                  let data = FileManager.default.contents(atPath: finalBundlePath) else {
                print("🔴 [ASSET_HANDLER] Asset not found: \(assetPath)")
                print("🔴 [ASSET_HANDLER] Attempted paths: \(attemptedPaths)")
                self.completeTask(urlSchemeTask, withError: NSError(domain: "IOSAssetHandler", code: 404, 
                                                      userInfo: [NSLocalizedDescriptionKey: "Asset not found: \(assetPath)"]))
                return
            }
        
        print("🟢 [ASSET_HANDLER] Found asset at: \(finalBundlePath)")
        
        // Determine MIME type
        let mimeType: String
        if assetPath.hasSuffix(".css") {
            mimeType = "text/css"
        } else if assetPath.hasSuffix(".js") {
            mimeType = "application/javascript"
        } else if assetPath.hasSuffix(".ttf") {
            mimeType = "font/ttf"
        } else {
            mimeType = "application/octet-stream"
        }
        
            guard let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: [
                "Content-Type": mimeType,
                "Content-Length": "\(data.count)"
            ]) else {
                print("❌ Failed to create HTTP response for \(assetPath)")
                self.completeTask(urlSchemeTask, withError: NSError(domain: "AssetHandler", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create HTTP response"]))
                return
            }
            
            self.completeTask(urlSchemeTask, withResponse: response, data: data)
            print("📱 iOS Asset Handler: Served \(assetPath) (\(data.count) bytes)")
        }
    }
    
    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {
        taskQueue.async {
            print("🛑 IOSAssetHandler: Stopping task: \(urlSchemeTask.request.url?.absoluteString ?? "unknown")")
            
            // Remove from active tasks to prevent completion attempts
            let taskId = ObjectIdentifier(urlSchemeTask)
            self.tasksLock.lock()
            if self.activeTasks.contains(taskId) {
                self.activeTasks.remove(taskId)
                self.tasksLock.unlock()
                print("✅ IOSAssetHandler: Task removed from active set")
            } else {
                self.tasksLock.unlock()
                print("⚠️ IOSAssetHandler: Task was already removed or never started")
            }
        }
    }
    
    // MARK: - Safe Task Completion Methods (Fix for race conditions)
    
    private func completeTask(_ urlSchemeTask: WKURLSchemeTask, withResponse response: HTTPURLResponse, data: Data) {
        taskQueue.async {
            // CRITICAL: Check if task is still active before completing
            let taskId = ObjectIdentifier(urlSchemeTask)
            self.tasksLock.lock()
            guard self.activeTasks.contains(taskId) else {
                self.tasksLock.unlock()
                print("⚠️ IOSAssetHandler: RACE CONDITION PREVENTED: Task already stopped, skipping completion")
                return
            }
            
            do {
                urlSchemeTask.didReceive(response)
                urlSchemeTask.didReceive(data)
                urlSchemeTask.didFinish()
                self.activeTasks.remove(taskId)
                self.tasksLock.unlock()
                print("✅ IOSAssetHandler: Task completed successfully")
            } catch {
                print("❌ IOSAssetHandler: Error completing task: \(error)")
                self.activeTasks.remove(taskId)
                self.tasksLock.unlock()
            }
        }
    }
    
    private func completeTask(_ urlSchemeTask: WKURLSchemeTask, withError error: Error) {
        taskQueue.async {
            // CRITICAL: Check if task is still active before failing
            let taskId = ObjectIdentifier(urlSchemeTask)
            self.tasksLock.lock()
            guard self.activeTasks.contains(taskId) else {
                self.tasksLock.unlock()
                print("⚠️ IOSAssetHandler: RACE CONDITION PREVENTED: Task already stopped, skipping error")
                return
            }
            
            do {
                urlSchemeTask.didFailWithError(error)
                self.activeTasks.remove(taskId)
                self.tasksLock.unlock()
                print("❌ IOSAssetHandler: Task failed with error: \(error.localizedDescription)")
            } catch {
                print("❌ IOSAssetHandler: Error failing task: \(error)")
                self.activeTasks.remove(taskId)
                self.tasksLock.unlock()
            }
        }
    }
    
    // MARK: - Image Proxying Methods
    
    private func handleImageProxy(urlSchemeTask: WKURLSchemeTask, assetPath: String) {
        // Convert custom scheme image request to original wiki URL
        let originalImageURL = "https://oldschool.runescape.wiki/\(assetPath)"
        
        guard let url = URL(string: originalImageURL) else {
            print("❌ IOSAssetHandler: Invalid image URL: \(originalImageURL)")
            self.completeTask(urlSchemeTask, withError: NSError(domain: "IOSAssetHandler", code: 400, userInfo: nil))
            return
        }
        
        print("🌐 IOSAssetHandler: Proxying image from: \(originalImageURL)")
        
        // Fetch the image from the original wiki
        let task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            if let error = error {
                print("❌ IOSAssetHandler: Image fetch failed: \(error.localizedDescription)")
                self?.completeTask(urlSchemeTask, withError: error)
                return
            }
            
            guard let data = data, let httpResponse = response as? HTTPURLResponse else {
                print("❌ IOSAssetHandler: No image data received")
                self?.completeTask(urlSchemeTask, withError: NSError(domain: "IOSAssetHandler", code: 404, userInfo: nil))
                return
            }
            
            print("✅ IOSAssetHandler: Image fetched successfully (\(data.count) bytes)")
            
            // Determine MIME type based on file extension
            let mimeType: String
            if assetPath.contains(".png") {
                mimeType = "image/png"
            } else if assetPath.contains(".jpg") || assetPath.contains(".jpeg") {
                mimeType = "image/jpeg"  
            } else if assetPath.contains(".gif") {
                mimeType = "image/gif"
            } else if assetPath.contains(".svg") {
                mimeType = "image/svg+xml"
            } else {
                mimeType = httpResponse.mimeType ?? "image/png"
            }
            
            // Create response with proper headers
            guard let requestUrl = urlSchemeTask.request.url,
                  let customResponse = HTTPURLResponse(
                url: requestUrl,
                statusCode: httpResponse.statusCode,
                httpVersion: "HTTP/1.1",
                headerFields: [
                    "Content-Type": mimeType,
                    "Content-Length": "\(data.count)",
                    "Cache-Control": "max-age=3600"
                ]
            ) else {
                print("❌ Failed to create HTTP response for image proxy")
                self?.completeTask(urlSchemeTask, withError: NSError(domain: "ImageProxy", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create HTTP response"]))
                return
            }
            
            self?.completeTask(urlSchemeTask, withResponse: customResponse, data: data)
            print("📱 iOS Image Proxy: Served \(assetPath) (\(data.count) bytes)")
        }
        
        task.resume()
    }
    
    private func handleMediaWikiProxy(urlSchemeTask: WKURLSchemeTask, assetPath: String) {
        // Convert custom scheme MediaWiki request to original wiki URL
        let originalURL: String
        if let queryString = urlSchemeTask.request.url?.query {
            originalURL = "https://oldschool.runescape.wiki/\(assetPath)?\(queryString)"
        } else {
            originalURL = "https://oldschool.runescape.wiki/\(assetPath)"
        }
        
        guard let url = URL(string: originalURL) else {
            print("❌ IOSAssetHandler: Invalid MediaWiki URL: \(originalURL)")
            self.completeTask(urlSchemeTask, withError: NSError(domain: "IOSAssetHandler", code: 400, userInfo: nil))
            return
        }
        
        print("🌐 IOSAssetHandler: Proxying MediaWiki resource from: \(originalURL)")
        
        // Fetch the resource from the original wiki
        let task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            if let error = error {
                print("❌ IOSAssetHandler: MediaWiki fetch failed: \(error.localizedDescription)")
                self?.completeTask(urlSchemeTask, withError: error)
                return
            }
            
            guard let data = data, let httpResponse = response as? HTTPURLResponse else {
                print("❌ IOSAssetHandler: No MediaWiki data received")
                self?.completeTask(urlSchemeTask, withError: NSError(domain: "IOSAssetHandler", code: 404, userInfo: nil))
                return
            }
            
            print("✅ IOSAssetHandler: MediaWiki resource fetched successfully (\(data.count) bytes)")
            
            // Use original response MIME type or default to JavaScript
            let mimeType = httpResponse.mimeType ?? "application/javascript"
            
            // Create response with proper headers
            guard let requestUrl = urlSchemeTask.request.url,
                  let customResponse = HTTPURLResponse(
                url: requestUrl,
                statusCode: httpResponse.statusCode,
                httpVersion: "HTTP/1.1", 
                headerFields: [
                    "Content-Type": mimeType,
                    "Content-Length": "\(data.count)",
                    "Cache-Control": "max-age=3600"
                ]
            ) else {
                print("❌ Failed to create HTTP response for MediaWiki proxy")
                self?.completeTask(urlSchemeTask, withError: NSError(domain: "MediaWikiProxy", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create HTTP response"]))
                return
            }
            
            self?.completeTask(urlSchemeTask, withResponse: customResponse, data: data)
            print("📱 iOS MediaWiki Proxy: Served \(assetPath) (\(data.count) bytes)")
        }
        
        task.resume()
    }
}

struct ArticleWebView: UIViewRepresentable {
    @ObservedObject var viewModel: ArticleViewModel
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: osrsThemeManager
    
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        
        // Configure user content controller for JavaScript bridge
        let userContentController = WKUserContentController()
        
        // Add clipboard bridge script
        let clipboardScript = WKUserScript(
            source: createClipboardBridgeScript(),
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: false
        )
        userContentController.addUserScript(clipboardScript)
        
        // Add render timeline logging script
        let renderTimelineScript = WKUserScript(
            source: createRenderTimelineScript(),
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: false
        )
        userContentController.addUserScript(renderTimelineScript)
        
        // Add mobile optimization script
        let mobileOptimizationScript = WKUserScript(
            source: createMobileOptimizationScript(),
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: false
        )
        userContentController.addUserScript(mobileOptimizationScript)
        
        // Note: MapLibre bridge loaded via external JS file (Option B) for cross-platform compatibility
        
        // Add Safari vs WKWebView debugging script
        let debuggingScript = WKUserScript(
            source: createSafariComparisonScript(),
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: false
        )
        userContentController.addUserScript(debuggingScript)
        
        // Register message handlers
        userContentController.add(context.coordinator, name: "clipboardBridge")
        userContentController.add(context.coordinator, name: "renderTimeline")
        userContentController.add(context.coordinator, name: "linkHandler")
        userContentController.add(context.coordinator, name: "mapBridge")
        userContentController.add(context.coordinator, name: "safariDebugger")
        
        configuration.userContentController = userContentController
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        
        // Option B: Register WKURLSchemeHandler for custom asset loading
        let assetHandler = IOSAssetHandler()
        let customScheme = "app-assets"
        
        // Register the custom scheme handler
        configuration.setURLSchemeHandler(assetHandler, forURLScheme: customScheme)
        UserDefaults.standard.set(customScheme, forKey: "WKURLSchemeHandler_Scheme")
        print("✅ Option B: Successfully registered \(customScheme):// URL scheme handler")
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = viewModel
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.bounces = true
        webView.isOpaque = false
        webView.backgroundColor = UIColor.clear
        
        // Enable debugging for Safari vs WKWebView comparison
        if #available(iOS 16.4, *) {
            webView.isInspectable = true
        }
        
        // Set up gesture recognizers for iOS-specific interactions
        setupGestureRecognizers(webView: webView)
        
        // Configure WebView for horizontal gesture support
        osrsWebViewBridge.configureWebView(webView)
        
        // Enable find-in-page interaction (iOS 16+)
        if #available(iOS 16.0, *) {
            webView.isFindInteractionEnabled = true
        }
        
        // Connect webView to viewModel
        viewModel.setWebView(webView)
        
        // Initialize map handler with the webView
        context.coordinator.setupMapHandler(webView: webView)
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        // Apply modern OSRS theme changes
        viewModel.injectThemeColors(themeManager)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    private func setupGestureRecognizers(webView: WKWebView) {
        // Add any iOS-specific gesture handling here
        // For example, double-tap to zoom, long press for context menu, etc.
    }
    
    private func createClipboardBridgeScript() -> String {
        return """
        (function() {
            // Create clipboard bridge similar to Android implementation
            window.ClipboardBridge = {
                writeText: function(text) {
                    window.webkit.messageHandlers.clipboardBridge.postMessage({
                        action: 'writeText',
                        text: text
                    });
                    return true;
                },
                
                readText: function() {
                    window.webkit.messageHandlers.clipboardBridge.postMessage({
                        action: 'readText'
                    });
                    return '';
                }
            };
            
            // Override navigator.clipboard for iframe compatibility
            if (navigator.clipboard) {
                const originalWriteText = navigator.clipboard.writeText;
                navigator.clipboard.writeText = function(text) {
                    return window.ClipboardBridge.writeText(text);
                };
            }
        })();
        """
    }
    
    private func createRenderTimelineScript() -> String {
        return """
        (function() {
            window.RenderTimeline = {
                log: function(message) {
                    window.webkit.messageHandlers.renderTimeline.postMessage({
                        message: message,
                        timestamp: Date.now()
                    });
                }
            };
            
            // Log key render events
            document.addEventListener('DOMContentLoaded', function() {
                window.RenderTimeline.log('Event: DOMContentLoaded');
            });
            
            window.addEventListener('load', function() {
                window.RenderTimeline.log('Event: WindowLoad');
            });
        })();
        """
    }
    
    private func createMobileOptimizationScript() -> String {
        return """
        (function() {
            // Mobile-specific optimizations
            
            // Prevent text selection on buttons and interactive elements
            const style = document.createElement('style');
            style.textContent = `
                button, .button, [role="button"], input[type="button"], input[type="submit"] {
                    -webkit-user-select: none;
                    user-select: none;
                    -webkit-touch-callout: none;
                }
                
                img {
                    -webkit-touch-callout: none;
                    -webkit-user-select: none;
                    user-select: none;
                }
                
                /* Improve touch targets */
                a, button, .button, [role="button"] {
                    min-height: 44px;
                    min-width: 44px;
                }
                
                /* Optimize tables for mobile */
                .wikitable {
                    font-size: 14px;
                    width: 100%;
                    table-layout: auto;
                }
                
                /* Handle horizontal overflow at container level */
                .collapsible-content {
                    overflow-x: auto;
                    -webkit-overflow-scrolling: touch;
                }
                
                /* Improve readability */
                .mw-parser-output {
                    line-height: 1.6;
                    font-size: 16px;
                }
            `;
            document.head.appendChild(style);
            
            // Handle internal links
            document.addEventListener('click', function(event) {
                const link = event.target.closest('a');
                if (link && link.href) {
                    const url = new URL(link.href);
                    const currentUrl = new URL(window.location.href);
                    
                    // Check if this is an internal wiki link
                    if (url.hostname === currentUrl.hostname || 
                        url.hostname.includes('runescape.wiki')) {
                        
                        window.webkit.messageHandlers.linkHandler.postMessage({
                            action: 'navigate',
                            url: link.href,
                            title: link.textContent || link.title || ''
                        });
                        
                        event.preventDefault();
                        return false;
                    }
                }
            });
        })();
        """
    }
    
    // Note: MapLibre bridge now loaded exclusively via external JS file (Option B)
    // This eliminates redundancy and provides cleaner cross-platform compatibility
    
    private func createSafariComparisonScript() -> String {
        return """
        (function() {
            // Safari vs WKWebView debugging script
            window.SafariDebugger = {
                analyzeEnvironment: function() {
                    const results = {
                        userAgent: navigator.userAgent,
                        viewport: {
                            innerWidth: window.innerWidth,
                            innerHeight: window.innerHeight,
                            devicePixelRatio: window.devicePixelRatio,
                            screen: { 
                                width: screen.width, 
                                height: screen.height,
                                availWidth: screen.availWidth,
                                availHeight: screen.availHeight
                            }
                        },
                        mediaQueries: {
                            mobile: window.matchMedia('(max-width: 768px)').matches,
                            tablet: window.matchMedia('(min-width: 769px) and (max-width: 1024px)').matches,
                            desktop: window.matchMedia('(min-width: 1025px)').matches,
                            retina: window.matchMedia('(-webkit-min-device-pixel-ratio: 2)').matches
                        },
                        fonts: {
                            defaultFamily: getComputedStyle(document.body).fontFamily,
                            defaultSize: getComputedStyle(document.body).fontSize
                        },
                        tables: this.analyzeTableRendering()
                    };
                    
                    window.webkit.messageHandlers.safariDebugger.postMessage({
                        type: 'environmentAnalysis',
                        data: results
                    });
                },
                
                analyzeTableRendering: function() {
                    const tables = document.querySelectorAll('table.wikitable');
                    const tableAnalysis = [];
                    
                    tables.forEach((table, index) => {
                        if (index < 3) { // Analyze first 3 tables
                            const tableStyles = window.getComputedStyle(table);
                            const cells = table.querySelectorAll('td');
                            const cellAnalysis = [];
                            
                            cells.forEach((cell, cellIndex) => {
                                if (cellIndex < 10) { // First 10 cells
                                    const cellStyles = window.getComputedStyle(cell);
                                    const rect = cell.getBoundingClientRect();
                                    const text = cell.textContent;
                                    
                                    // Test if text would wrap
                                    const testSpan = document.createElement('span');
                                    testSpan.style.cssText = 'position: absolute; visibility: hidden; white-space: nowrap; font-family: inherit; font-size: inherit;';
                                    testSpan.textContent = text;
                                    document.body.appendChild(testSpan);
                                    const singleLineWidth = testSpan.getBoundingClientRect().width;
                                    document.body.removeChild(testSpan);
                                    
                                    cellAnalysis.push({
                                        cellIndex: cellIndex,
                                        text: text.substring(0, 50),
                                        textLength: text.length,
                                        cellWidth: rect.width,
                                        cellHeight: rect.height,
                                        singleLineWidth: singleLineWidth,
                                        isWrapping: singleLineWidth > rect.width && text.length > 10,
                                        styles: {
                                            width: cellStyles.width,
                                            maxWidth: cellStyles.maxWidth,
                                            minWidth: cellStyles.minWidth,
                                            wordWrap: cellStyles.wordWrap,
                                            overflowWrap: cellStyles.overflowWrap,
                                            wordBreak: cellStyles.wordBreak,
                                            whiteSpace: cellStyles.whiteSpace,
                                            textSizeAdjust: cellStyles.webkitTextSizeAdjust || cellStyles.textSizeAdjust,
                                            display: cellStyles.display,
                                            fontSize: cellStyles.fontSize,
                                            fontFamily: cellStyles.fontFamily
                                        }
                                    });
                                }
                            });
                            
                            tableAnalysis.push({
                                tableIndex: index,
                                cellsAnalyzed: cellAnalysis.length,
                                wrappingCells: cellAnalysis.filter(c => c.isWrapping).length,
                                tableStyles: {
                                    width: tableStyles.width,
                                    tableLayout: tableStyles.tableLayout,
                                    borderCollapse: tableStyles.borderCollapse,
                                    wordWrap: tableStyles.wordWrap,
                                    overflowWrap: tableStyles.overflowWrap
                                },
                                cells: cellAnalysis
                            });
                        }
                    });
                    
                    return {
                        tablesFound: tables.length,
                        tablesAnalyzed: tableAnalysis.length,
                        totalWrappingCells: tableAnalysis.reduce((sum, table) => sum + table.wrappingCells, 0),
                        analysis: tableAnalysis
                    };
                }
            };
            
            // Run analysis after page load
            if (document.readyState === 'complete') {
                setTimeout(() => window.SafariDebugger.analyzeEnvironment(), 1000);
            } else {
                window.addEventListener('load', () => {
                    setTimeout(() => window.SafariDebugger.analyzeEnvironment(), 1000);
                });
            }
        })();
        """
    }
    
    class Coordinator: NSObject, WKScriptMessageHandler {
        let parent: ArticleWebView
        private var mapHandler: osrsNativeMapHandler?
        
        init(_ parent: ArticleWebView) {
            self.parent = parent
        }
        
        func setupMapHandler(webView: WKWebView) {
            mapHandler = osrsNativeMapHandler(webView: webView)
            print("✅ iOS ArticleWebView: Map handler initialized")
        }
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let body = message.body as? [String: Any] else { return }
            
            switch message.name {
            case "clipboardBridge":
                handleClipboardMessage(body)
            case "renderTimeline":
                handleRenderTimelineMessage(body)
            case "linkHandler":
                handleLinkMessage(body)
            case "mapBridge":
                handleMapBridgeMessage(body)
            case "safariDebugger":
                handleSafariDebuggerMessage(body)
            default:
                break
            }
        }
        
        private func handleClipboardMessage(_ body: [String: Any]) {
            guard let action = body["action"] as? String else { return }
            
            switch action {
            case "writeText":
                if let text = body["text"] as? String {
                    UIPasteboard.general.string = text
                    print("Clipboard: Successfully copied text via iOS bridge")
                }
            case "readText":
                let text = UIPasteboard.general.string ?? ""
                // Note: Reading clipboard on iOS requires returning the value differently
                // This would need to be implemented with a callback mechanism
                print("Clipboard: Read text request (iOS has limitations)")
            default:
                break
            }
        }
        
        private func handleRenderTimelineMessage(_ body: [String: Any]) {
            if let message = body["message"] as? String,
               let timestamp = body["timestamp"] as? Double {
                let timeString = DateFormatter.timeFormatter.string(from: Date())
                print("📊 [\(timeString)] 🎯 RenderTimeline: \(message)")
                
                // Handle specific render events
                if message == "Event: StylingScriptsComplete" {
                    // ANDROID PARITY: JavaScript is ready - now wait for body reveal completion
                    DispatchQueue.main.async {
                        // TIMING MEASUREMENT: Record JavaScript completion time
                        let jsCompletionTime = Date()
                        let jsCompletionTimeString = DateFormatter.timeFormatter.string(from: jsCompletionTime)
                        
                        if let progressTime = self.parent.viewModel.progressCompletionTime {
                            let delay = jsCompletionTime.timeIntervalSince(progressTime)
                            self.parent.viewModel.lastMeasuredDelay = delay
                            print("📊 [\(jsCompletionTimeString)] 🟢 JAVASCRIPT COMPLETE: WebKit-to-JS delay: \(String(format: "%.3f", delay))s")
                        }
                        
                        // Progress stays at 95% until body reveal is complete
                        self.parent.viewModel.loadingProgress = 0.97
                        self.parent.viewModel.loadingProgressText = "Revealing content..."
                        print("📊 [\(jsCompletionTimeString)] 🎯 JS READY: Progressing to 97%, waiting for body reveal...")
                        
                        // Trigger body reveal and complete progress when it's done
                        self.parent.viewModel.completeLoadingWithBodyReveal()
                    }
                } else {
                    print("📊 [\(timeString)] 📝 OTHER JS EVENT: \(message)")
                }
            }
        }
        
        private func handleLinkMessage(_ body: [String: Any]) {
            guard let action = body["action"] as? String,
                  action == "navigate",
                  let urlString = body["url"] as? String,
                  let url = URL(string: urlString) else { return }
            
            let title = body["title"] as? String ?? ""
            
            DispatchQueue.main.async {
                // Navigate to new article within the app
                self.parent.appState.navigateToArticle(title: title, url: url)
            }
        }
        
        private func handleMapBridgeMessage(_ body: [String: Any]) {
            guard let action = body["action"] as? String else { 
                print("🔴 MapBridge: Received message with no action: \(body)")
                return 
            }
            
            print("🟢 MapBridge: Received action '\(action)' with data: \(body)")
            
            switch action {
            case "onMapPlaceholderMeasured":
                if let id = body["id"] as? String,
                   let rectJson = body["rectJson"] as? String,
                   let mapDataJson = body["mapDataJson"] as? String {
                    mapHandler?.onMapPlaceholderMeasured(id: id, rectJson: rectJson, mapDataJson: mapDataJson)
                }
                
            case "onCollapsibleToggled":
                if let mapId = body["mapId"] as? String,
                   let isOpening = body["isOpening"] as? Bool {
                    mapHandler?.onCollapsibleToggled(mapId: mapId, isOpening: isOpening)
                }
                
            case "setHorizontalScroll":
                if let inProgress = body["inProgress"] as? Bool {
                    mapHandler?.setHorizontalScroll(inProgress: inProgress)
                }
                
            case "log":
                if let message = body["message"] as? String {
                    mapHandler?.log(message: message)
                }
                
            default:
                print("❌ iOS ArticleWebView: Unknown map bridge action: \(action)")
            }
        }
        
        private func handleSafariDebuggerMessage(_ body: [String: Any]) {
            guard let type = body["type"] as? String,
                  let data = body["data"] as? [String: Any] else { return }
            
            switch type {
            case "environmentAnalysis":
                print("🔍 Safari Debugger: Environment Analysis Results")
                print("=" + String(repeating: "=", count: 50))
                
                if let userAgent = data["userAgent"] as? String {
                    print("📱 User Agent: \(userAgent)")
                }
                
                if let viewport = data["viewport"] as? [String: Any] {
                    print("📐 Viewport: \(viewport)")
                }
                
                if let mediaQueries = data["mediaQueries"] as? [String: Any] {
                    print("📺 Media Queries: \(mediaQueries)")
                }
                
                if let fonts = data["fonts"] as? [String: Any] {
                    print("🔤 Fonts: \(fonts)")
                }
                
                if let tables = data["tables"] as? [String: Any] {
                    print("📊 Tables Analysis:")
                    if let tablesFound = tables["tablesFound"] as? Int,
                       let totalWrappingCells = tables["totalWrappingCells"] as? Int {
                        print("  - Tables found: \(tablesFound)")
                        print("  - Total wrapping cells: \(totalWrappingCells)")
                    }
                    
                    if let analysis = tables["analysis"] as? [[String: Any]] {
                        for (index, tableData) in analysis.enumerated() {
                            if let wrappingCells = tableData["wrappingCells"] as? Int,
                               let cellsAnalyzed = tableData["cellsAnalyzed"] as? Int {
                                print("  - Table \(index): \(wrappingCells)/\(cellsAnalyzed) cells wrapping")
                            }
                        }
                    }
                }
                
                print("=" + String(repeating: "=", count: 50))
                
                // Save the results to a file for comparison with Safari web results
                DispatchQueue.global(qos: .background).async {
                    do {
                        let jsonData = try JSONSerialization.data(withJSONObject: data, options: .prettyPrinted)
                        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                        let fileURL = documentsPath.appendingPathComponent("wkwebview-analysis.json")
                        try jsonData.write(to: fileURL)
                        print("💾 WKWebView analysis saved to: \(fileURL.path)")
                    } catch {
                        print("❌ Failed to save WKWebView analysis: \(error)")
                    }
                }
                
            default:
                print("🔍 Safari Debugger: Unknown message type: \(type)")
            }
        }
    }
}

#Preview {
    ArticleWebView(viewModel: ArticleViewModel(pageUrl: URL(string: "about:blank")!))
        .environmentObject(AppState())
        .environmentObject(osrsThemeManager.preview)
}