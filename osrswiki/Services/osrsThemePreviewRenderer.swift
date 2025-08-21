//
//  osrsThemePreviewRenderer.swift
//  OSRS Wiki
//
//  iOS equivalent to Android's ThemePreviewRenderer
//  Generates visual theme previews by rendering actual app interface screenshots
//

import SwiftUI
import UIKit
import Combine

/// Generates theme preview images by rendering actual app interfaces with different themes applied
@MainActor
class osrsThemePreviewRenderer: ObservableObject {
    
    // Singleton instance for shared cache
    static let shared = osrsThemePreviewRenderer()
    
    // Preview dimensions - larger size to show more content (based on actual card size in screenshot)
    private static let targetPreviewSize: CGSize = CGSize(width: 300, height: 200)
    
    // Cache for generated previews
    private var previewCache: [String: UIImage] = [:]
    
    // Private initializer to ensure singleton usage
    private init() {}
    
    /// Generate preview image for a specific theme
    func generatePreview(for theme: osrsThemeSelection, colorScheme: ColorScheme? = nil) async -> UIImage {
        let colorSchemeKey = colorScheme == .light ? "light" : colorScheme == .dark ? "dark" : "auto"
        let cacheKey = "\(theme.rawValue)-\(colorSchemeKey)"
        
        print("🖼️ ThemePreviewRenderer: Generating preview for \(theme.rawValue)")
        
        // Check cache first
        if let cachedImage = previewCache[cacheKey] {
            print("⚡ ThemePreviewRenderer: CACHE HIT for \(cacheKey) - returning cached image instantly")
            return cachedImage
        }
        
        print("🔄 ThemePreviewRenderer: CACHE MISS for \(cacheKey) - generating new preview (this will be slow)")
        
        // Generate new preview
        let previewImage: UIImage
        
        switch theme {
        case .automatic:
            print("🖼️ ThemePreviewRenderer: Generating split preview for automatic theme")
            previewImage = await generateSplitPreview()
        case .osrsLight:
            print("🖼️ ThemePreviewRenderer: Generating light theme preview")
            previewImage = await generateSingleThemePreview(theme: theme, forceColorScheme: .light)
        case .osrsDark:
            print("🖼️ ThemePreviewRenderer: Generating dark theme preview")
            previewImage = await generateSingleThemePreview(theme: theme, forceColorScheme: .dark)
        }
        
        print("🖼️ ThemePreviewRenderer: Generated image size: \(previewImage.size)")
        
        // Cache the result for future instant access
        previewCache[cacheKey] = previewImage
        print("💾 ThemePreviewRenderer: CACHED image for \(cacheKey) - future loads will be instant")
        return previewImage
    }
    
    /// Generate split preview showing light theme on left, dark theme on right (for "Follow system")
    private func generateSplitPreview() async -> UIImage {
        // CRITICAL FIX: Use cached generatePreview instead of bypassing cache with direct generateSingleThemePreview calls
        let lightPreview = await generatePreview(for: .osrsLight)
        let darkPreview = await generatePreview(for: .osrsDark)
        
        return combineImagesLeftRight(leftImage: lightPreview, rightImage: darkPreview)
    }
    
    /// Generate single theme preview using ACTUAL app interface with pre-loaded content (like Android)
    private func generateSingleThemePreview(theme: osrsThemeSelection, forceColorScheme: ColorScheme) async -> UIImage {
        let resolvedTheme = theme.theme(for: forceColorScheme)
        
        print("🖼️ ThemePreviewRenderer: Loading real content for \(theme.rawValue) theme...")
        
        print("🖼️ ThemePreviewRenderer: Pre-loading data then rendering NewsView")
        
        // Create real app state and theme manager
        let appState = AppState()
        let themeManager = osrsThemeManager()
        themeManager.setTheme(theme)
        
        // Pre-load NewsViewModel data BEFORE creating the view to avoid timing issues
        let newsViewModel = NewsViewModel()
        await newsViewModel.loadNews()
        
        print("🖼️ ThemePreviewRenderer: Data loaded, wikiFeed: \(newsViewModel.wikiFeed != nil ? "✅" : "❌"), updates count: \(newsViewModel.wikiFeed?.recentUpdates.count ?? 0)")
        
        // Extract wikiFeed data to avoid @Published timing issues in UIHostingController
        guard let wikiFeed = newsViewModel.wikiFeed else {
            print("🖼️ ThemePreviewRenderer: No wikiFeed data, using fallback")
            return await generateFallbackPreview(theme: resolvedTheme)
        }
        
        print("🖼️ ThemePreviewRenderer: Pre-loading images for theme preview...")
        
        // Pre-load all images for reliable theme preview rendering (solves AsyncImage issues)
        let imageCache = osrsImageCache.shared
        await imageCache.preloadImages(from: wikiFeed.recentUpdates)
        
        print("🖼️ ThemePreviewRenderer: Creating StaticNewsView with pre-loaded images")
        
        // Create StaticNewsView with direct data (no ObservableObject dependencies)
        let staticNewsView = StaticNewsView(wikiFeed: wikiFeed)
            .environmentObject(appState)
            .environmentObject(themeManager)
            .environment(\.osrsTheme, resolvedTheme)
            .environment(\.colorScheme, forceColorScheme)
            .environment(\.osrsPreviewMode, true)
        
        // Render at device size and scale down with async waiting for image loading
        return await renderViewWithImageLoadWait(staticNewsView, targetSize: Self.targetPreviewSize)
    }
    
    /// Generate fallback preview when content loading fails
    private func generateFallbackPreview(theme: any osrsThemeProtocol) async -> UIImage {
        let size = Self.targetPreviewSize
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            // Fill background
            UIColor(theme.background).setFill()
            context.fill(CGRect(origin: .zero, size: size))
            
            // Draw simple preview indicator
            let text = "Preview"
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
    
    /// Render view with async waiting for image loading (fixing theme preview images)
    private func renderViewWithImageLoadWait(_ view: some View, targetSize: CGSize) async -> UIImage {
        // Get device screen bounds (like Android getAppContentBounds)
        let deviceSize = await getDeviceContentSize()
        
        print("🖼️ Rendering at device size: \(deviceSize), then scaling to: \(targetSize)")
        
        // First render at full device size with image load waiting
        let deviceImage = await renderViewWithImageWait(view, size: deviceSize)
        
        // Then scale down to target preview size
        return scaleImageToTargetSize(deviceImage, targetSize: targetSize)
    }
    
    /// Render view at device size then scale down (like Android approach)
    private func renderViewAtDeviceSizeThenScale(_ view: some View, targetSize: CGSize) async -> UIImage {
        // Get device screen bounds (like Android getAppContentBounds)
        let deviceSize = await getDeviceContentSize()
        
        print("🖼️ Rendering at device size: \(deviceSize), then scaling to: \(targetSize)")
        
        // First render at full device size
        let deviceImage = await renderViewToImage(view, size: deviceSize)
        
        // Then scale down to target preview size
        return scaleImageToTargetSize(deviceImage, targetSize: targetSize)
    }
    
    /// Render view to image with proper async image loading waiting
    private func renderViewWithImageWait(_ view: some View, size: CGSize) async -> UIImage {
        return await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                // Create hosting controller
                let controller = UIHostingController(rootView: view)
                
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
                
                // Wait for pre-loaded NewsView to render (images already cached, no AsyncImage delays)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    // Force ScrollView to scroll to top for proper alignment
                    self.forceScrollToTop(in: controller.view)
                    
                    // Additional layout after image loading and scroll positioning
                    controller.view.setNeedsLayout()
                    controller.view.layoutIfNeeded()
                    
                    // Render to image
                    let renderer = UIGraphicsImageRenderer(size: size)
                    let image = renderer.image { context in
                        // Set clear background
                        context.cgContext.clear(CGRect(origin: .zero, size: size))
                        
                        // Render the view
                        controller.view.layer.render(in: context.cgContext)
                    }
                    
                    // Clean up
                    window.isHidden = true
                    window.rootViewController = nil
                    
                    print("🖼️ Rendered image with top alignment: size \(image.size), scale \(image.scale)")
                    continuation.resume(returning: image)
                }
            }
        }
    }
    
    /// Force all ScrollViews to scroll to top for proper alignment
    private func forceScrollToTop(in view: UIView) {
        // Find all UIScrollViews in the view hierarchy
        let scrollViews = findAllScrollViews(in: view)
        
        for scrollView in scrollViews {
            print("🖼️ Found ScrollView, forcing to top: current offset \(scrollView.contentOffset)")
            
            // Scroll to the very top
            scrollView.contentOffset = CGPoint(x: 0, y: -scrollView.adjustedContentInset.top)
            scrollView.setNeedsLayout()
            scrollView.layoutIfNeeded()
            
            print("🖼️ ScrollView forced to top: new offset \(scrollView.contentOffset)")
        }
    }
    
    /// Recursively find all UIScrollViews in view hierarchy
    private func findAllScrollViews(in view: UIView) -> [UIScrollView] {
        var scrollViews: [UIScrollView] = []
        
        if let scrollView = view as? UIScrollView {
            scrollViews.append(scrollView)
        }
        
        for subview in view.subviews {
            scrollViews.append(contentsOf: findAllScrollViews(in: subview))
        }
        
        return scrollViews
    }
    
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
                print("🖼️ Device content size: \(contentSize) (full: \(fullSize), insets: \(safeAreaInsets))")
                
                continuation.resume(returning: contentSize)
            }
        }
    }
    
    /// Scale image to target size, fit to width, preserve aspect ratio, anchor to top
    private func scaleImageToTargetSize(_ sourceImage: UIImage, targetSize: CGSize) -> UIImage {
        let sourceSize = sourceImage.size
        
        // Scale to fit width exactly (preserve aspect ratio)
        let scale = targetSize.width / sourceSize.width
        let scaledHeight = sourceSize.height * scale
        
        print("🖼️ TOP-ANCHOR scaling from \(sourceSize) with scale \(scale) (target: \(targetSize))")
        print("🖼️ Scaled height: \(scaledHeight), target height: \(targetSize.height)")
        
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { context in
            // Draw the scaled image anchored to the top
            let sourceRect = CGRect(origin: .zero, size: sourceSize)
            let targetRect = CGRect(x: 0, y: 0, width: targetSize.width, height: scaledHeight)
            
            print("🖼️ Drawing source \(sourceRect) to target \(targetRect), clipped to \(targetSize)")
            
            // Set clipping to target size to crop bottom if needed
            context.cgContext.clip(to: CGRect(origin: .zero, size: targetSize))
            
            // Draw the entire source image scaled to fit width, anchored to top
            sourceImage.draw(in: targetRect)
        }
    }
    
    /// Render a SwiftUI view to UIImage with proper view hierarchy
    private func renderViewToImage(_ view: some View, size: CGSize) async -> UIImage {
        return await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                // Create hosting controller
                let controller = UIHostingController(rootView: view)
                
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
                    // Render to image
                    let renderer = UIGraphicsImageRenderer(size: size)
                    let image = renderer.image { context in
                        // Set clear background
                        context.cgContext.clear(CGRect(origin: .zero, size: size))
                        
                        // Render the view
                        controller.view.layer.render(in: context.cgContext)
                    }
                    
                    // Clean up
                    window.isHidden = true
                    window.rootViewController = nil
                    
                    print("🖼️ Rendered image size: \(image.size), scale: \(image.scale)")
                    continuation.resume(returning: image)
                }
            }
        }
    }
    
    /// Combine two images side by side with divider, preserving aspect ratio
    private func combineImagesLeftRight(leftImage: UIImage, rightImage: UIImage) -> UIImage {
        let size = Self.targetPreviewSize
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            let halfWidth = size.width / 2
            
            // Scale images to fit half-width while preserving aspect ratio
            let leftScaledImage = scaleImagePreservingAspectRatio(leftImage, targetSize: CGSize(width: halfWidth, height: size.height))
            let rightScaledImage = scaleImagePreservingAspectRatio(rightImage, targetSize: CGSize(width: halfWidth, height: size.height))
            
            // Draw left half - center in available space
            let leftRect = CGRect(x: (halfWidth - leftScaledImage.size.width) / 2, 
                                y: (size.height - leftScaledImage.size.height) / 2, 
                                width: leftScaledImage.size.width, 
                                height: leftScaledImage.size.height)
            leftScaledImage.draw(in: leftRect)
            
            // Draw right half - center in available space
            let rightRect = CGRect(x: halfWidth + (halfWidth - rightScaledImage.size.width) / 2, 
                                 y: (size.height - rightScaledImage.size.height) / 2, 
                                 width: rightScaledImage.size.width, 
                                 height: rightScaledImage.size.height)
            rightScaledImage.draw(in: rightRect)
            
            // Draw divider line
            context.cgContext.setStrokeColor(UIColor.systemGray.cgColor)
            context.cgContext.setLineWidth(1.0)
            context.cgContext.move(to: CGPoint(x: halfWidth, y: 0))
            context.cgContext.addLine(to: CGPoint(x: halfWidth, y: size.height))
            context.cgContext.strokePath()
        }
    }
    
    /// Scale image to fit target size while preserving aspect ratio (no cropping)
    private func scaleImagePreservingAspectRatio(_ sourceImage: UIImage, targetSize: CGSize) -> UIImage {
        let sourceSize = sourceImage.size
        
        // Calculate scale to fit (not fill) - use min to preserve aspect ratio
        let scaleX = targetSize.width / sourceSize.width
        let scaleY = targetSize.height / sourceSize.height
        let scale = min(scaleX, scaleY)  // Use min to fit completely (no cropping)
        
        let scaledSize = CGSize(width: sourceSize.width * scale, height: sourceSize.height * scale)
        
        let renderer = UIGraphicsImageRenderer(size: scaledSize)
        return renderer.image { _ in
            sourceImage.draw(in: CGRect(origin: .zero, size: scaledSize))
        }
    }
    
    
    /// Clear all cached previews
    /// Get cached preview image without regenerating (for instant access)
    func getCachedPreview(for theme: osrsThemeSelection, colorScheme: ColorScheme? = nil) -> UIImage? {
        let colorSchemeKey = colorScheme == .light ? "light" : colorScheme == .dark ? "dark" : "auto"
        let cacheKey = "\(theme.rawValue)-\(colorSchemeKey)"
        return previewCache[cacheKey]
    }
    
    func clearCache() {
        previewCache.removeAll()
    }
}

