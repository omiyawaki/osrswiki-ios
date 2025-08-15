//
//  ArticleWebView.swift
//  OSRS Wiki
//
//  Created on iOS webviewer implementation session
//

import SwiftUI
import WebKit

struct ArticleWebView: UIViewRepresentable {
    @ObservedObject var viewModel: ArticleViewModel
    @EnvironmentObject var appState: AppState
    
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
        
        // Register message handlers
        userContentController.add(context.coordinator, name: "clipboardBridge")
        userContentController.add(context.coordinator, name: "renderTimeline")
        userContentController.add(context.coordinator, name: "linkHandler")
        
        configuration.userContentController = userContentController
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = viewModel
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.bounces = true
        webView.isOpaque = false
        webView.backgroundColor = UIColor.clear
        
        // Set up gesture recognizers for iOS-specific interactions
        setupGestureRecognizers(webView: webView)
        
        // Connect webView to viewModel
        viewModel.setWebView(webView)
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        // Apply theme changes
        viewModel.injectThemeColors(appState.currentTheme)
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
                    overflow-x: auto;
                    display: block;
                    white-space: nowrap;
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
    
    class Coordinator: NSObject, WKScriptMessageHandler {
        let parent: ArticleWebView
        
        init(_ parent: ArticleWebView) {
            self.parent = parent
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
                print("RenderTimeline: \(message) at \(timestamp)")
                
                // Handle specific render events
                if message == "Event: StylingScriptsComplete" {
                    // Similar to Android's page ready callback
                    DispatchQueue.main.async {
                        self.parent.viewModel.isLoading = false
                    }
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
    }
}

#Preview {
    ArticleWebView(viewModel: ArticleViewModel(pageUrl: URL(string: "https://oldschool.runescape.wiki/w/Dragon")!))
        .environmentObject(AppState())
}