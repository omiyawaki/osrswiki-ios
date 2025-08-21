//
//  osrsNativeMapHandler.swift
//  OSRS Wiki
//
//  iOS equivalent of Android's NativeMapHandler for in-article MapLibre embeds
//

import SwiftUI
import UIKit
import WebKit
import MapLibre
import CoreLocation

// MARK: - Data Models (matching Android JSON structure)

struct osrsMapRect: Codable {
    let y: Double
    let x: Double  
    let width: Double
    let height: Double
}

struct osrsMapData: Codable {
    let lat: String?
    let lon: String?
    let zoom: String?
    let plane: String?
}

// MARK: - Native Map Handler

class osrsNativeMapHandler: NSObject {
    weak var articleWebView: WKWebView?
    private var mapContainers: [String: UIView] = [:]
    
    // CRITICAL FIX: Store delegates and MapViews to prevent deallocation (Android pattern)
    private var mapDelegates: [String: osrsEmbeddedMapDelegate] = [:]
    private var mapViews: [String: MLNMapView] = [:]
    
    private let offscreenTranslationX: CGFloat = -2000.0
    
    @Published var isHorizontalScrollInProgress = false
    
    init(webView: WKWebView) {
        self.articleWebView = webView
        super.init()
        setupScrollListener()
        
        // CRITICAL FIX: Copy MBTiles to Documents like Android copies to filesDir
        copyMBTilesToDocuments()
    }
    
    // MARK: - MBTiles Management (Android Pattern)
    
    private func copyMBTilesToDocuments() {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        
        for floor in 0...3 {
            let fileName = "map_floor_\(floor).mbtiles"
            let destinationURL = documentsURL.appendingPathComponent(fileName)
            
            // Skip if already exists
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                print("📂 MBTiles already exists: \(fileName)")
                continue
            }
            
            // Copy from bundle to Documents
            guard let bundlePath = Bundle.main.path(forResource: "map_floor_\(floor)", ofType: "mbtiles") else {
                print("❌ MBTiles not found in bundle: \(fileName)")
                continue
            }
            
            do {
                try FileManager.default.copyItem(atPath: bundlePath, toPath: destinationURL.path)
                print("✅ Copied MBTiles to Documents: \(fileName)")
            } catch {
                print("❌ Failed to copy MBTiles \(fileName): \(error)")
            }
        }
    }
    
    // MARK: - JavaScript Bridge Methods (equivalent to @JavascriptInterface)
    
    func onMapPlaceholderMeasured(id: String, rectJson: String, mapDataJson: String) {
        print("🔥 CRITICAL DEBUG: onMapPlaceholderMeasured called for \(id)")
        print("🔥 Rect JSON: \(rectJson)")
        print("🔥 Map Data JSON: \(mapDataJson)")
        
        guard let webView = articleWebView else { 
            print("❌ CRITICAL: No articleWebView found")
            return 
        }
        
        do {
            let rectData = rectJson.data(using: .utf8)!
            let mapDataData = mapDataJson.data(using: .utf8)!
            
            let rect = try JSONDecoder().decode(osrsMapRect.self, from: rectData)
            let mapData = try JSONDecoder().decode(osrsMapData.self, from: mapDataData)
            
            print("🔥 Parsed rect: x=\(rect.x), y=\(rect.y), w=\(rect.width), h=\(rect.height)")
            print("🔥 Parsed mapData: lat=\(mapData.lat ?? "nil"), lon=\(mapData.lon ?? "nil"), zoom=\(mapData.zoom ?? "nil"), plane=\(mapData.plane ?? "nil")")
            
            DispatchQueue.main.async {
                print("🔥 CRITICAL: About to call preloadMap")
                self.preloadMap(id: id, rect: rect, mapData: mapData, webView: webView)
                print("🔥 CRITICAL: preloadMap call completed")
            }
        } catch {
            print("❌ CRITICAL ERROR: Failed to parse JSON - \(error)")
        }
    }
    
    func onCollapsibleToggled(mapId: String, isOpening: Bool) {
        print("🗺️ iOS Map Handler: onCollapsibleToggled - \(mapId), opening: \(isOpening)")
        
        guard let webView = articleWebView,
              let container = mapContainers[mapId] else { return }
        
        DispatchQueue.main.async {
            // CRITICAL FIX: Use frame-based positioning like Android uses LayoutParams
            // Android: view.translationX = if (isOpening) 0f else offscreenTranslationX
            
            if isOpening {
                // Show the native map container, hide the WebView placeholder
                // Move container to visible position by adjusting frame (Android equivalent: translationX = 0)
                var frame = container.frame
                frame.origin.x = frame.origin.x - self.offscreenTranslationX // Bring back from offscreen
                container.frame = frame
                
                let script = "document.getElementById('\(mapId)').style.opacity = 0;"
                webView.evaluateJavaScript(script)
                print("✅ iOS Map Handler: Showing native map for \(mapId)")
            } else {
                // Hide the native map container, show the WebView placeholder
                // Move container offscreen by adjusting frame (Android equivalent: translationX = offscreenTranslationX)
                var frame = container.frame
                frame.origin.x = frame.origin.x + self.offscreenTranslationX // Move offscreen
                container.frame = frame
                
                let script = "document.getElementById('\(mapId)').style.opacity = 1;"
                webView.evaluateJavaScript(script)
                print("✅ iOS Map Handler: Hiding native map for \(mapId)")
            }
        }
    }
    
    func setHorizontalScroll(inProgress: Bool) {
        print("🗺️ iOS Map Handler: setHorizontalScroll - \(inProgress)")
        self.isHorizontalScrollInProgress = inProgress
    }
    
    func log(message: String) {
        print("🗺️ JS: \(message)")
    }
    
    // MARK: - Private Implementation
    
    private func preloadMap(id: String, rect: osrsMapRect, mapData: osrsMapData, webView: WKWebView) {
        print("🔥 CRITICAL: preloadMap started for \(id)")
        
        // Don't create duplicate containers
        if mapContainers[id] != nil {
            print("🔥 CRITICAL: Container \(id) already exists - skipping")
            return
        }
        
        // CRITICAL FIX: Use parent view like Android uses binding.root (parent ConstraintLayout)
        // Android: binding.root.addView(container)
        guard let parentView = webView.superview else {
            print("❌ CRITICAL ERROR: No parent view for WebView")
            print("🔥 WebView hierarchy: \(webView)")
            return
        }
        
        print("🔥 CRITICAL: Found parent view: \(type(of: parentView))")
        
        // Create container view (equivalent to Android's FragmentContainerView)
        let container = UIView()
        container.backgroundColor = UIColor.clear
        container.isHidden = false // Visible but positioned off-screen
        container.layer.zPosition = 10 // Equivalent to elevation
        
        // Position will be set in frame calculation below (no transforms needed)
        
        // CRITICAL FIX: Add to parent view like Android adds to binding.root
        parentView.addSubview(container)
        mapContainers[id] = container
        
        // Apply WebView scale and positioning (matching Android calculation exactly)
        let scale = webView.scrollView.zoomScale
        let correction: CGFloat = 1.0 // iOS density-independent pixel equivalent
        
        // CRITICAL FIX: Use rect dimensions directly like Android
        let width = rect.width + correction // Don't apply scale to width - use original rect size
        let height = rect.height // Don't apply scale to height - use original rect size
        
        // CRITICAL FIX: Use frame-based positioning instead of Auto Layout constraints
        // This matches Android's direct LayoutParams approach better
        // Account for WebView's scroll position in calculation (like Android topMargin/marginStart)
        let webViewContentOffset = webView.scrollView.contentOffset
        let topMargin = webView.frame.origin.y + rect.y - webViewContentOffset.y // No scale - use original rect position
        let leftMargin = webView.frame.origin.x + rect.x - webViewContentOffset.x // No scale - use original rect position
        
        print("🎯 iOS Map Handler: Positioning container - width:\(width), height:\(height), top:\(topMargin), left:\(leftMargin), scale:\(scale)")
        print("🔍 iOS Map Handler: WebView frame: \(webView.frame), rect: x:\(rect.x) y:\(rect.y)")
        
        // Store original Y offset in tag for scroll handling (relative to WebView content)
        container.tag = Int(rect.y) // Use original rect.y, not scaled
        
        // Set frame directly (matching Android's direct positioning approach)
        container.frame = CGRect(
            x: leftMargin + offscreenTranslationX, // Start offscreen
            y: topMargin,
            width: width,
            height: height
        )
        
        // Create embedded MapLibre view with proper retention
        let mapView = createEmbeddedMapView(mapData: mapData, mapId: id)
        container.addSubview(mapView)
        
        // Fill container
        mapView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            mapView.topAnchor.constraint(equalTo: container.topAnchor),
            mapView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            mapView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            mapView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        
        print("🔥 CRITICAL SUCCESS: Created embedded map container \(id)")
        print("🔥 Container frame: \(container.frame)")
        print("🔥 Container superview: \(container.superview != nil ? "YES" : "NO")")
        print("🔥 MapView frame: \(mapView.frame)")
        print("🔥 Total containers: \(mapContainers.count)")
    }
    
    // MARK: - Coordinate Conversion
    
    /// Convert OSRS in-game coordinates to geographical coordinates for MapLibre
    /// This matches the Android implementation exactly
    private func gameToLatLng(gameX: Double, gameY: Double) -> CLLocationCoordinate2D {
        let gameCoordScale = 4.0
        let gameMinX = 1024.0
        let gameMaxY = 12608.0
        let canvasSize = 65536.0
        
        let px = (gameX - gameMinX) * gameCoordScale
        let py = (gameMaxY - gameY) * gameCoordScale
        let nx = px / canvasSize
        let ny = py / canvasSize
        
        let lon = -180.0 + nx * 360.0
        let lat = atan(sinh(.pi * (1.0 - 2.0 * ny))) * 180.0 / .pi
        
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
    
    private func createEmbeddedMapView(mapData: osrsMapData, mapId: String) -> MLNMapView {
        let mapView = MLNMapView()
        
        // Configure like main map but optimized for embedding
        mapView.logoView.isHidden = true
        mapView.attributionButton.isHidden = true
        mapView.compassView.isHidden = true
        mapView.showsScale = false
        mapView.allowsRotating = false // Disable rotation for embeds
        mapView.allowsTilting = false
        mapView.allowsZooming = true
        mapView.allowsScrolling = true
        
        // Parse OSRS in-game coordinates
        let gameX = Double(mapData.lon ?? "") ?? 3200.0 // Note: OSRS wiki uses lon for X coordinate
        let gameY = Double(mapData.lat ?? "") ?? 3200.0 // Note: OSRS wiki uses lat for Y coordinate  
        let zoom = 6.0 // CRITICAL FIX: Use hardcoded zoom like Android (not JSON zoom value)
        let plane = Int(mapData.plane ?? "0") ?? 0
        
        print("🎯 iOS Map Handler: Converting OSRS coordinates gameX:\(gameX), gameY:\(gameY), zoom:\(zoom), plane:\(plane)")
        
        // Convert OSRS coordinates to geographical coordinates (matching Android implementation)
        let geographicalCoords = gameToLatLng(gameX: gameX, gameY: gameY)
        
        print("🌍 iOS Map Handler: Converted to geographical lat:\(geographicalCoords.latitude), lon:\(geographicalCoords.longitude)")
        
        // Set initial position using converted coordinates
        mapView.setCenter(geographicalCoords, zoomLevel: zoom, animated: false)
        
        // CRITICAL FIX: Store MapView to prevent deallocation (Android pattern)
        mapViews[mapId] = mapView
        
        // Set up map style and tiles (reuse logic from main map)
        setupEmbeddedMapStyle(mapView: mapView, targetFloor: plane, mapId: mapId)
        
        return mapView
    }
    
    private func setupEmbeddedMapStyle(mapView: MLNMapView, targetFloor: Int, mapId: String) {
        // CRITICAL FIX: Use the same style JSON as the main map to ensure tiles load
        // This matches Android's approach of using the same map configuration
        let customStyleJSON = """
        {
            "version": 8,
            "name": "OSRS Embedded Map Style",
            "sources": {},
            "layers": [
                {
                    "id": "background",
                    "type": "background",
                    "paint": {
                        "background-color": "#000000"
                    }
                }
            ]
        }
        """
        
        let tempDirectory = FileManager.default.temporaryDirectory
        let styleURL = tempDirectory.appendingPathComponent("osrs-embedded-style-\(mapId).json")
        
        do {
            try customStyleJSON.write(to: styleURL, atomically: true, encoding: .utf8)
            mapView.styleURL = styleURL
            
            // CRITICAL FIX: Store delegate to prevent deallocation (Android pattern)
            let delegate = osrsEmbeddedMapDelegate(targetFloor: targetFloor, mapId: mapId)
            mapDelegates[mapId] = delegate  // Retain delegate
            mapView.delegate = delegate
            
            print("✅ iOS Map Handler: Set up embedded map style for floor \(targetFloor), mapId: \(mapId)")
            
        } catch {
            print("❌ iOS Map Handler: Failed to setup embedded map style - \(error)")
        }
    }
    
    private func setupScrollListener() {
        guard let webView = articleWebView else { return }
        
        // Observe WebView scroll changes to keep map containers in sync
        webView.scrollView.addObserver(self, forKeyPath: "contentOffset", options: .new, context: nil)
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, 
                              change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "contentOffset" {
            guard let webView = articleWebView else { return }
            let scrollY = webView.scrollView.contentOffset.y
            
            // CRITICAL FIX: Use frame-based scroll handling instead of transforms
            // Match Android's translationY = -scrollY behavior using frames
            for container in mapContainers.values {
                var frame = container.frame
                // Adjust Y position based on scroll offset, keeping original relative position
                frame.origin.y = webView.frame.origin.y + CGFloat(container.tag) - scrollY
                container.frame = frame
            }
        }
    }
    
    // MARK: - Cleanup
    
    func cleanup() {
        print("🗺️ iOS Map Handler: Cleaning up \(mapContainers.count) map containers")
        
        // Remove all containers
        for container in mapContainers.values {
            container.removeFromSuperview()
        }
        mapContainers.removeAll()
        
        // CRITICAL FIX: Clean up retained delegates and MapViews (Android pattern)
        mapDelegates.removeAll()
        mapViews.removeAll()
        
        // Remove scroll observer
        articleWebView?.scrollView.removeObserver(self, forKeyPath: "contentOffset")
        
        isHorizontalScrollInProgress = false
    }
    
    deinit {
        cleanup()
    }
}

// MARK: - Embedded Map Delegate

class osrsEmbeddedMapDelegate: NSObject, MLNMapViewDelegate {
    private let targetFloor: Int
    private let mapId: String
    
    init(targetFloor: Int, mapId: String) {
        self.targetFloor = targetFloor
        self.mapId = mapId
        super.init()
    }
    
    func mapView(_ mapView: MLNMapView, didFinishLoading style: MLNStyle) {
        print("🔥 CRITICAL SUCCESS: Style loaded for floor \(targetFloor), mapId: \(mapId)")
        print("🔥 MapView bounds: \(mapView.bounds)")
        print("🔥 Style layers count: \(style.layers.count)")
        
        // Add background
        if let backgroundLayer = style.layer(withIdentifier: "background") as? MLNBackgroundStyleLayer {
            backgroundLayer.backgroundColor = NSExpression(forConstantValue: UIColor.black)
            print("🔥 Background layer configured")
        }
        
        // Add floor layers using same logic as main map
        print("🔥 About to add floor layer for floor \(targetFloor)")
        addFloorLayer(floor: targetFloor, to: style, mapView: mapView)
        
        // If viewing upper floor, add ground floor as underlay
        if targetFloor > 0 {
            print("🔥 Adding ground floor underlay")
            addFloorLayer(floor: 0, to: style, mapView: mapView, opacity: 0.5)
        }
        
        print("🔥 CRITICAL: Style setup complete for \(mapId)")
    }
    
    private func addFloorLayer(floor: Int, to style: MLNStyle, mapView: MLNMapView, opacity: Double = 1.0) {
        let sourceId = "osrs-embedded-source-\(floor)"
        let layerId = "osrs-embedded-layer-\(floor)"
        let fileName = "map_floor_\(floor).mbtiles"
        
        // CRITICAL FIX: Use Documents directory like Android uses filesDir
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let documentsPath = documentsURL.appendingPathComponent(fileName).path
        
        var mbtilesPath: String?
        
        // Check Documents directory first (copied from bundle like Android)
        if FileManager.default.fileExists(atPath: documentsPath) {
            mbtilesPath = documentsPath
            print("📂 Embedded Map: Using copied MBTiles from Documents: \(fileName)")
        } else if let bundlePath = Bundle.main.path(forResource: "map_floor_\(floor)", ofType: "mbtiles") {
            mbtilesPath = bundlePath
            print("📦 Embedded Map: Fallback to bundle MBTiles: \(fileName)")
        }
        
        guard let validPath = mbtilesPath else {
            print("❌ Embedded Map: MBTiles file not found: \(fileName)")
            print("❌ Embedded Map: Checked Documents directory (\(documentsPath)) and bundle")
            return
        }
        
        let mbtilesURLString = "mbtiles://\(validPath)"
        print("🗺️ Embedded Map: Loading tiles from: \(mbtilesURLString)")
        
        let rasterSource = MLNRasterTileSource(
            identifier: sourceId,
            configurationURL: URL(string: mbtilesURLString)!
        )
        
        style.addSource(rasterSource)
        
        let rasterLayer = MLNRasterStyleLayer(identifier: layerId, source: rasterSource)
        rasterLayer.rasterResamplingMode = NSExpression(forConstantValue: "nearest")
        rasterLayer.rasterOpacity = NSExpression(forConstantValue: opacity)
        
        style.addLayer(rasterLayer)
        
        print("🔥 CRITICAL SUCCESS: Added floor \(floor) layer with opacity \(opacity)")
        print("🔥 Source: \(sourceId)")
        print("🔥 Layer: \(layerId)")  
        print("🔥 Path: \(validPath)")
        print("🔥 Style now has \(style.layers.count) layers")
    }
}