//
//  osrsTablePreviewRenderer.swift
//  OSRS Wiki
//
//  iOS equivalent to Android's TablePreviewRenderer
//  Generates table collapse previews using actual wiki content
//

import SwiftUI
import UIKit
import WebKit

/// Generates table collapse preview images by rendering actual wiki content
@MainActor
class osrsTablePreviewRenderer: ObservableObject {
    
    // Singleton instance for shared cache
    static let shared = osrsTablePreviewRenderer()
    
    // No fixed dimensions - return full device-sized renders
    
    // Cache for generated previews
    private var previewCache: [String: UIImage] = [:]
    
    // Private initializer to ensure singleton usage
    private init() {}
    
    /// Generate preview showing expanded vs collapsed table states
    func generateTablePreview(collapsed: Bool, theme: any osrsThemeProtocol) async -> UIImage {
        let cacheKey = "table-\(collapsed ? "collapsed" : "expanded")-\(theme.name)"
        
        print("📊 TablePreviewRenderer: Generating preview for \(collapsed ? "collapsed" : "expanded") table")
        
        // Check cache first
        if let cachedImage = previewCache[cacheKey] {
            print("📊 TablePreviewRenderer: Found cached image for \(cacheKey)")
            return cachedImage
        }
        
        // Generate new preview using SwiftUI rendering
        let previewImage = await generateWebViewTablePreview(collapsed: collapsed, theme: theme)
        
        print("📊 TablePreviewRenderer: Generated table image size: \(previewImage.size)")
        
        // Cache the result
        previewCache[cacheKey] = previewImage
        return previewImage
    }
    
    /// Generate table preview using ACTUAL ArticleView with real Varrock Wikipedia content
    private func generateWebViewTablePreview(collapsed: Bool, theme: any osrsThemeProtocol) async -> UIImage {
        // Create app state and theme manager for ArticleView environment
        let appState = AppState()
        let themeManager = osrsThemeManager()
        
        // CRITICAL FIX: Set the theme manager to match the preview theme to prevent contamination
        if theme.name.lowercased().contains("light") {
            themeManager.setTheme(.osrsLight)
        } else if theme.name.lowercased().contains("dark") {
            themeManager.setTheme(.osrsDark)
        }
        
        print("📊 TablePreviewRenderer: Set theme manager to \(themeManager.selectedTheme.rawValue) for \(theme.name) preview")
        
        // Use REAL ArticleView pointing to actual Varrock Wikipedia page
        let varrockUrl = URL(string: "https://oldschool.runescape.wiki/w/Varrock")!
        // Create a mock overlay manager for preview rendering
        let mockOverlayManager = GlobalOverlayManager()
        
        let realArticleView = ArticleView(pageTitle: "Varrock", pageUrl: varrockUrl, collapseTablesEnabled: collapsed)
            .environmentObject(appState)
            .environmentObject(themeManager)
            .environment(\.osrsTheme, theme)
            .overlayManager(mockOverlayManager) // Provide mock overlay manager
        
        // Render real WebView content with proper async waiting (like Android)
        let deviceSize = await getDeviceContentSize()
        return await renderRealWebViewWithWait(realArticleView, targetSize: deviceSize, collapsed: collapsed)
    }
    
    /// Render real WebView with proper async waiting for page load (like Android approach)
    private func renderRealWebViewWithWait(_ view: some View, targetSize: CGSize, collapsed: Bool) async -> UIImage {
        // Get device screen bounds (like Android getAppContentBounds)
        let deviceSize = await getDeviceContentSize()
        
        print("📊 Rendering REAL WebView at device size: \(deviceSize), then scaling to: \(targetSize)")
        
        // First render at full device size with WebView load waiting
        let deviceImage = await renderRealWebViewToImageWithWait(view, size: deviceSize, collapsed: collapsed)
        
        // Then scale down to target preview size
        return scaleImageToTargetSize(deviceImage, targetSize: targetSize)
    }
    
    /// Render real WebView to image with proper async page load waiting
    private func renderRealWebViewToImageWithWait(_ view: some View, size: CGSize, collapsed: Bool) async -> UIImage {
        return await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                // Create hosting controller with view wrapped to ignore safe area
                let wrappedView = view
                    .ignoresSafeArea()
                    .frame(width: size.width, height: size.height)
                
                let controller = UIHostingController(rootView: wrappedView)
                controller.view.insetsLayoutMarginsFromSafeArea = false
                
                // Create a temporary window to provide proper view hierarchy
                let window = UIWindow(frame: CGRect(origin: .zero, size: size))
                window.rootViewController = controller
                window.isHidden = false
                
                // Set the controller's view frame
                controller.view.frame = CGRect(origin: .zero, size: size)
                controller.view.backgroundColor = UIColor.clear
                
                // Force layout cycle
                controller.view.setNeedsLayout()
                controller.view.layoutIfNeeded()
                
                // Wait longer for WebView to load real Varrock content AND execute JavaScript table collapse
                DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self, weak controller, weak window] in
                    // Check if view controller is still valid (not deallocated during navigation)
                    guard let controller = controller, controller.view.window != nil else {
                        print("⚠️ TablePreviewRenderer: Controller deallocated, cancelling render")
                        continuation.resume(returning: UIImage())
                        return
                    }
                    
                    // Force JavaScript execution to ensure table state is correct
                    self?.forceTableStateInWebView(controller: controller, collapsed: collapsed)
                    
                    // Additional layout after WebView content loads
                    controller.view.setNeedsLayout()
                    controller.view.layoutIfNeeded()
                    
                    // Get the actual content area (excluding safe area)
                    let safeAreaTop = controller.view.safeAreaInsets.top
                    let contentHeight = size.height - safeAreaTop
                    let contentSize = CGSize(width: size.width, height: contentHeight)
                    
                    // Render to image, cropping out the top safe area
                    let renderer = UIGraphicsImageRenderer(size: contentSize)
                    let image = renderer.image { context in
                        // Set clear background
                        context.cgContext.clear(CGRect(origin: .zero, size: contentSize))
                        
                        // Translate to skip the safe area at top
                        context.cgContext.translateBy(x: 0, y: -safeAreaTop)
                        
                        // Render the real WebView
                        controller.view.layer.render(in: context.cgContext)
                    }
                    
                    // Clean up
                    if let window = window {
                        window.isHidden = true
                        window.rootViewController = nil
                    }
                    
                    print("📊 Rendered REAL WebView image size: \(image.size), cropped \(safeAreaTop)pt from top")
                    continuation.resume(returning: image)
                }
            }
        }
    }
    
    // Removed renderViewAtDeviceSizeThenScale - no longer needed
    
    /// Get device content size (excluding system UI like Android)
    private func getDeviceContentSize() async -> CGSize {
        return await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                // Get main screen bounds
                let screen = UIScreen.main
                let fullSize = screen.bounds.size
                
                // Account for safe area (like Android system UI)
                let window = UIApplication.shared.connectedScenes
                    .compactMap { $0 as? UIWindowScene }
                    .first?.windows.first
                
                let safeAreaInsets = window?.safeAreaInsets ?? UIEdgeInsets.zero
                
                // Calculate content area (excluding system UI)
                let contentWidth = fullSize.width
                let contentHeight = fullSize.height - safeAreaInsets.top - safeAreaInsets.bottom
                
                let contentSize = CGSize(width: contentWidth, height: contentHeight)
                print("📊 Device content size: \(contentSize) (full: \(fullSize), insets: \(safeAreaInsets))")
                
                continuation.resume(returning: contentSize)
            }
        }
    }
    
    /// Scale image to target size maintaining aspect ratio
    private func scaleImageToTargetSize(_ sourceImage: UIImage, targetSize: CGSize) -> UIImage {
        let sourceSize = sourceImage.size
        
        // Scale to FILL the target size (use max to ensure no letterboxing)
        let scaleX = targetSize.width / sourceSize.width
        let scaleY = targetSize.height / sourceSize.height
        let scale = max(scaleX, scaleY) // Use max to fill completely
        
        let scaledWidth = sourceSize.width * scale
        let scaledHeight = sourceSize.height * scale
        
        print("📊 FILL scaling from \(sourceSize) to \(scaledWidth)x\(scaledHeight) (target: \(targetSize))")
        
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { context in
            // Center the scaled image and crop excess
            let x = (targetSize.width - scaledWidth) / 2
            let y = (targetSize.height - scaledHeight) / 2
            let drawRect = CGRect(x: x, y: y, width: scaledWidth, height: scaledHeight)
            
            // Set clipping to target size
            context.cgContext.clip(to: CGRect(origin: .zero, size: targetSize))
            
            // Draw the scaled image centered
            sourceImage.draw(in: drawRect)
        }
    }
    
    
    /// Render a SwiftUI view to UIImage with proper view hierarchy
    private func renderViewToImage(_ view: some View, size: CGSize) async -> UIImage {
        return await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                // Create hosting controller with view wrapped to ignore safe area
                let wrappedView = view
                    .ignoresSafeArea()
                    .frame(width: size.width, height: size.height)
                
                let controller = UIHostingController(rootView: wrappedView)
                controller.view.insetsLayoutMarginsFromSafeArea = false
                
                // Create a temporary window to provide proper view hierarchy
                let window = UIWindow(frame: CGRect(origin: .zero, size: size))
                window.rootViewController = controller
                window.isHidden = false
                
                // Set the controller's view frame
                controller.view.frame = CGRect(origin: .zero, size: size)
                controller.view.backgroundColor = UIColor.clear
                
                // Force layout cycle
                controller.view.setNeedsLayout()
                controller.view.layoutIfNeeded()
                
                // Wait for next run loop to ensure layout is complete
                DispatchQueue.main.async {
                    // Get the actual content area
                    let safeAreaTop = controller.view.safeAreaInsets.top
                    let contentHeight = size.height - safeAreaTop
                    let contentSize = CGSize(width: size.width, height: contentHeight)
                    
                    // Render to image, cropping out the top safe area
                    let renderer = UIGraphicsImageRenderer(size: contentSize)
                    let image = renderer.image { context in
                        // Set clear background
                        context.cgContext.clear(CGRect(origin: .zero, size: contentSize))
                        
                        // Translate to skip the safe area at top
                        context.cgContext.translateBy(x: 0, y: -safeAreaTop)
                        
                        // Render the view
                        controller.view.layer.render(in: context.cgContext)
                    }
                    
                    // Clean up
                    window.isHidden = true
                    window.rootViewController = nil
                    
                    print("📊 Rendered table image size: \(image.size), cropped \(safeAreaTop)pt from top")
                    continuation.resume(returning: image)
                }
            }
        }
    }
    
    /// Generate fallback image when WebView rendering fails
    private func generateFallbackTableImage(collapsed: Bool, theme: any osrsThemeProtocol) -> UIImage {
        let size = CGSize(width: 300, height: 200) // Fallback size
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            // Fill background
            UIColor(theme.background).setFill()
            context.fill(CGRect(origin: .zero, size: size))
            
            // Draw simple text
            let text = collapsed ? "Collapsed" : "Expanded"
            let font = UIFont.systemFont(ofSize: 14, weight: .medium)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: UIColor(theme.onSurface)
            ]
            
            let textSize = text.size(withAttributes: attributes)
            let textRect = CGRect(
                x: (size.width - textSize.width) / 2,
                y: (size.height - textSize.height) / 2,
                width: textSize.width,
                height: textSize.height
            )
            
            text.draw(in: textRect, withAttributes: attributes)
        }
    }
    
    /// Force table state in WebView by executing JavaScript directly
    private func forceTableStateInWebView(controller: UIHostingController<some View>, collapsed: Bool) {
        // Find the WKWebView in the view hierarchy
        if let webView = findWebView(in: controller.view) {
            let collapsedState = collapsed ? "true" : "false"
            let stateDescription = collapsed ? "collapsed" : "expanded"
            let jsCode = """
                console.log('TablePreviewRenderer: Forcing table state to \(stateDescription)');
                
                // Set the global variable
                window.OSRS_TABLE_COLLAPSED = \(collapsedState);
                
                // Debug: Check what tables are on the page
                var allTables = document.querySelectorAll('table');
                console.log('TablePreviewRenderer: Found ' + allTables.length + ' total tables');
                
                // Force all collapsible elements to the desired state
                var collapsibleElements = document.querySelectorAll('.mw-collapsible');
                console.log('TablePreviewRenderer: Found ' + collapsibleElements.length + ' collapsible elements');
                
                collapsibleElements.forEach(function(element, index) {
                    console.log('TablePreviewRenderer: Element ' + index + ' initial classes: ' + element.className);
                    
                    if (\(collapsedState)) {
                        // Collapse the element
                        if (!element.classList.contains('mw-collapsed')) {
                            element.classList.add('mw-collapsed');
                            console.log('TablePreviewRenderer: Collapsed element ' + index + ' -> classes: ' + element.className);
                        }
                    } else {
                        // Expand the element
                        if (element.classList.contains('mw-collapsed')) {
                            element.classList.remove('mw-collapsed');
                            console.log('TablePreviewRenderer: Expanded element ' + index + ' -> classes: ' + element.className);
                        }
                    }
                });
                
                // Debug: Count visible table rows
                var visibleRows = document.querySelectorAll('table tr:not([style*="display: none"])');
                console.log('TablePreviewRenderer: Found ' + visibleRows.length + ' visible table rows after state change');
                
                // Force re-render by triggering a style recalculation
                document.body.style.display = 'none';
                document.body.offsetHeight; // Trigger reflow
                document.body.style.display = '';
                
                console.log('TablePreviewRenderer: Forced table state completed');
            """
            
            webView.evaluateJavaScript(jsCode) { result, error in
                if let error = error {
                    print("📊 TablePreviewRenderer: JavaScript execution error: \(error)")
                } else {
                    print("📊 TablePreviewRenderer: Successfully forced table state to \(stateDescription)")
                }
            }
        } else {
            print("📊 TablePreviewRenderer: Could not find WKWebView in view hierarchy")
        }
    }
    
    /// Recursively find WKWebView in view hierarchy
    private func findWebView(in view: UIView) -> WKWebView? {
        if let webView = view as? WKWebView {
            return webView
        }
        
        for subview in view.subviews {
            if let webView = findWebView(in: subview) {
                return webView
            }
        }
        
        return nil
    }
    
    /// Get cached table preview image without regenerating (for instant access)
    func getCachedTablePreview(collapsed: Bool, theme: any osrsThemeProtocol) -> UIImage? {
        let cacheKey = "table-\(collapsed ? "collapsed" : "expanded")-\(theme.name)"
        return previewCache[cacheKey]
    }
    
    /// Clear all cached previews
    func clearCache() {
        previewCache.removeAll()
    }
}


/// Extension to convert UIColor to hex string
private extension UIColor {
    func toHex() -> String {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        let rgb = Int(red * 255) << 16 | Int(green * 255) << 8 | Int(blue * 255)
        return String(format: "#%06X", rgb)
    }
}



/// Extension to add name property to theme protocol
extension osrsThemeProtocol {
    var name: String {
        if self is osrsLightTheme {
            return "light"
        } else if self is osrsDarkTheme {
            return "dark"
        } else {
            return "unknown"
        }
    }
}