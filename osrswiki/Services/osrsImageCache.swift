//
//  osrsImageCache.swift
//  OSRS Wiki
//
//  Image cache for theme preview generation - pre-loads images synchronously
//  Solves AsyncImage issues in UIHostingController rendering contexts
//

import UIKit
import SwiftUI

/// Synchronous image cache for theme preview rendering
@MainActor
class osrsImageCache: ObservableObject {
    
    static let shared = osrsImageCache()
    
    private var imageCache: [String: UIImage] = [:]
    private let urlSession = URLSession.shared
    
    private init() {}
    
    /// Pre-load images from news items for theme preview rendering
    func preloadImages(from updateItems: [UpdateItem]) async {
        print("🖼️ Pre-loading \(updateItems.count) images for theme preview...")
        
        await withTaskGroup(of: Void.self) { group in
            for item in updateItems {
                group.addTask {
                    await self.loadAndCacheImage(url: item.imageUrl, key: item.imageUrl)
                }
            }
        }
        
        print("🖼️ Pre-loading complete. Cached \(imageCache.count) images")
    }
    
    /// Load and cache a single image synchronously
    private func loadAndCacheImage(url: String, key: String) async {
        guard let imageUrl = URL(string: url) else { return }
        
        do {
            let (data, _) = try await urlSession.data(from: imageUrl)
            if let image = UIImage(data: data) {
                await MainActor.run {
                    imageCache[key] = image
                    print("🖼️ Cached image: \(key)")
                }
            }
        } catch {
            print("❌ Failed to load image: \(url) - \(error)")
        }
    }
    
    /// Get cached image synchronously (for use in SwiftUI views)
    func getCachedImage(for url: String) -> UIImage? {
        return imageCache[url]
    }
    
    /// Clear all cached images
    func clearCache() {
        imageCache.removeAll()
        print("🗑️ Image cache cleared")
    }
}