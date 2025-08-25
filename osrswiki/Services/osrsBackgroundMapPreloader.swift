//
//  osrsBackgroundMapPreloader.swift
//  OSRS Wiki
//
//  Background MapLibre preloading service - creates ONE shared map instance on app launch
//  Main map view reuses this pre-initialized instance for instant display
//

import SwiftUI
import MapLibre
import UIKit

/// Background MapLibre preloading manager - creates shared map instance for instant loading
@MainActor
class osrsBackgroundMapPreloader: NSObject, ObservableObject {
    
    static let shared = osrsBackgroundMapPreloader()
    
    // SHARED map instance that gets reused by the main map view
    private(set) var sharedMapView: MLNMapView?
    private var sharedMapContainer: UIView?
    
    // State tracking
    @Published private(set) var isPreloadingMap = false
    @Published private(set) var preloadingProgress: Double = 0.0
    @Published private(set) var mapPreloaded = false
    @Published private(set) var allLayersReady = false
    
    private override init() {
        super.init()
    }
    
    /// Create the shared MapLibre instance with all layers pre-created
    func preloadMapInBackground() async {
        guard !isPreloadingMap else {
            print("🗺️ Background map preloading already in progress")
            return
        }
        
        await MainActor.run {
            isPreloadingMap = true
            preloadingProgress = 0.0
            mapPreloaded = false
            allLayersReady = false
        }
        
        print("🚀 PRIORITY: Creating shared MapLibre instance with all layers (takes precedence)...")
        
        // Step 1: Create the shared MapLibre view
        await updateProgress(0.1, "Creating shared MapLibre instance...")
        await createSharedMapView()
        
        // Step 2: Wait for style to load
        await updateProgress(0.3, "Loading map style...")
        await waitForStyleToLoad()
        
        // Step 3: Pre-create all floor layers
        await updateProgress(0.5, "Pre-creating all floor layers...")
        await preCreateAllFloorLayers()
        
        // Step 4: Mark as ready
        await updateProgress(1.0, "Shared map instance ready!")
        await MainActor.run {
            mapPreloaded = true
            allLayersReady = true
            isPreloadingMap = false
        }
        
        print("✅ PRIORITY: Shared MapLibre instance ready - main map can reuse it instantly!")
    }
    
    /// Create the shared MapLibre view that will be reused
    private func createSharedMapView() async {
        // Create off-screen container
        sharedMapContainer = UIView(frame: CGRect(x: -2000, y: -2000, width: 400, height: 600))
        sharedMapView = MLNMapView(frame: sharedMapContainer!.bounds)
        
        guard let mapView = sharedMapView else { return }
        
        // Configure exactly like the main map
        mapView.delegate = self
        mapView.logoView.isHidden = true
        mapView.attributionButton.isHidden = true
        mapView.compassView.isHidden = false
        mapView.showsScale = false
        mapView.allowsRotating = true
        mapView.allowsTilting = false
        mapView.prefetchesTiles = true
        
        // Set position to Lumbridge
        let center = CLLocationCoordinate2D(
            latitude: -25.2023457171692,  // MapConstants.defaultLat
            longitude: -131.44071698586012 // MapConstants.defaultLon
        )
        mapView.setCenter(center, zoomLevel: 7.3414426741929, animated: false)
        print("🔥 SHARED MAP: Initial zoom set to 7.34, center: \(center)")
        
        // Set OSRS map bounds to prevent panning beyond actual game content
        // Source image: 12800x45568 pixels, scale: 4 pixels per game unit
        let gameMinX = 1024.0
        let gameMaxX = gameMinX + (12800.0 / 4.0) // gameMinX + image_width / scale = 1024 + 3200 = 4224
        let gameMaxY = 12608.0
        let gameMinY = gameMaxY - (45568.0 / 4.0) // gameMaxY - image_height / scale = 12608 - 11392 = 1216
        
        // Convert game coordinates to lat/lng bounds
        let northWest = gameToLatLng(gameX: gameMinX, gameY: gameMinY)
        let southEast = gameToLatLng(gameX: gameMaxX, gameY: gameMaxY)
        
        let contentBounds = MLNCoordinateBounds(
            sw: southEast, // southWest corner
            ne: northWest  // northEast corner
        )
        await mapView.setVisibleCoordinateBounds(contentBounds, edgePadding: UIEdgeInsets.zero, animated: false)
        print("🔥 SHARED MAP: After setting bounds - zoom: \(mapView.zoomLevel), center: \(mapView.centerCoordinate)")
        
        // Set zoom limits: min zoom 0, max zoom 12
        mapView.minimumZoomLevel = 0.0
        mapView.maximumZoomLevel = 12.0
        
        // CRITICAL FIX: Restore proper zoom after setVisibleCoordinateBounds override
        // Root cause discovered: setVisibleCoordinateBounds() calculated zoom 0.77 to fit world bounds
        // Tiles have minimum zoom of 1.0, so zoom 0.77 = black screen (no tiles rendered)
        // Solution: Always validate and restore zoom after bounds operations
        if mapView.zoomLevel < 1.0 {
            print("🔥 SHARED MAP: Zoom was reset to \(mapView.zoomLevel), fixing to 7.34")
            mapView.setCenter(center, zoomLevel: 7.3414426741929, animated: false)
            print("🔥 SHARED MAP: Fixed zoom: \(mapView.zoomLevel), center: \(mapView.centerCoordinate)")
        }
        
        // Add to off-screen container and attach to window
        sharedMapContainer?.addSubview(mapView)
        
        if let keyWindow = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow }) {
            
            keyWindow.addSubview(sharedMapContainer!)
            print("🗺️ Shared MapLibre view created off-screen")
        }
        
        // Set up custom style
        setupCustomMapStyle()
    }
    
    /// Set up the custom map style
    private func setupCustomMapStyle() {
        guard let mapView = sharedMapView else { return }
        
        let customStyleJSON = """
        {
            "version": 8,
            "name": "OSRS Map Style (Shared Instance)",
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
        let styleURL = tempDirectory.appendingPathComponent("osrs-shared-map-style.json")
        
        do {
            try customStyleJSON.write(to: styleURL, atomically: true, encoding: .utf8)
            mapView.styleURL = styleURL
            print("✅ Shared map custom style set")
        } catch {
            print("❌ Failed to write shared map style: \(error)")
        }
    }
    
    /// Wait for the map style to load
    private func waitForStyleToLoad() async {
        for _ in 0..<100 { // 10 second timeout
            if sharedMapView?.style != nil {
                print("✅ Shared map style loaded successfully")
                return
            }
            try? await Task.sleep(for: .milliseconds(100))
        }
        print("⚠️ Shared map style load timeout")
    }
    
    /// Pre-create all floor layers in the shared map
    private func preCreateAllFloorLayers() async {
        guard let style = sharedMapView?.style else {
            print("❌ Shared map style not available for layer creation")
            return
        }
        
        print("🚀 Pre-creating all floor layers in shared map instance...")
        
        for floor in 0...3 {
            let progress = 0.5 + (Double(floor) / 4.0) * 0.5
            await updateProgress(progress, "Creating floor \(floor) layer...")
            
            await createFloorLayer(floor: floor, in: style)
            print("✅ Shared map: Floor \(floor) layer created")
        }
        
        print("✅ All floor layers pre-created in shared map instance")
    }
    
    /// Create a single floor layer
    private func createFloorLayer(floor: Int, in style: MLNStyle) async {
        let sourceId = "osrs-source-\(floor)"
        let layerId = "osrs-layer-\(floor)"
        let fileName = "map_floor_\(floor)"
        
        print("🗺️ SHARED MAP: Creating floor \(floor) layer")
        
        // Find MBTiles file
        var mbtilesPath: String?
        var mbtilesFileSize: UInt64 = 0
        
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let documentsPath = documentsURL.appendingPathComponent("\(fileName).mbtiles").path
        
        if FileManager.default.fileExists(atPath: documentsPath) {
            mbtilesPath = documentsPath
            if let attributes = try? FileManager.default.attributesOfItem(atPath: documentsPath) {
                mbtilesFileSize = attributes[.size] as? UInt64 ?? 0
            }
            print("🗺️ SHARED MAP: Using Documents MBTiles for floor \(floor): \(mbtilesFileSize) bytes")
        } else if let bundlePath = Bundle.main.path(forResource: fileName, ofType: "mbtiles") {
            mbtilesPath = bundlePath
            if let attributes = try? FileManager.default.attributesOfItem(atPath: bundlePath) {
                mbtilesFileSize = attributes[.size] as? UInt64 ?? 0
            }
            print("🗺️ SHARED MAP: Using Bundle MBTiles for floor \(floor): \(mbtilesFileSize) bytes")
        }
        
        guard let validPath = mbtilesPath else {
            print("❌ SHARED MAP: MBTiles not found for floor \(floor)")
            return
        }
        
        if mbtilesFileSize == 0 {
            print("❌ SHARED MAP: MBTiles file is empty for floor \(floor)")
            return
        }
        
        // Create source and layer
        let mbtilesURLString = "mbtiles://\(validPath)"
        print("🗺️ SHARED MAP: MBTiles URL for floor \(floor): \(mbtilesURLString)")
        
        let rasterSource = MLNRasterTileSource(
            identifier: sourceId,
            configurationURL: URL(string: mbtilesURLString)!
        )
        
        print("🗺️ SHARED MAP: Adding source \(sourceId)")
        style.addSource(rasterSource)
        
        // Verify source was added
        if style.source(withIdentifier: sourceId) != nil {
            print("✅ SHARED MAP: Source \(sourceId) added successfully")
        } else {
            print("❌ SHARED MAP: Failed to add source \(sourceId)")
            return
        }
        
        let rasterLayer = MLNRasterStyleLayer(identifier: layerId, source: rasterSource)
        rasterLayer.rasterResamplingMode = NSExpression(forConstantValue: "nearest")
        rasterLayer.isVisible = true // Always visible (opacity-based control)
        
        // Set initial opacity
        let initialOpacity: Double = floor == 0 ? 1.0 : 0.0
        rasterLayer.rasterOpacity = NSExpression(forConstantValue: initialOpacity)
        
        // Performance settings
        rasterLayer.maximumZoomLevel = 12
        rasterLayer.minimumZoomLevel = 0
        
        print("🗺️ SHARED MAP: Adding layer \(layerId) with opacity \(initialOpacity)")
        style.addLayer(rasterLayer)
        
        // Verify layer was added
        if let addedLayer = style.layer(withIdentifier: layerId) {
            print("✅ SHARED MAP: Layer \(layerId) added successfully")
            if let rasterLayerCheck = addedLayer as? MLNRasterStyleLayer {
                print("✅ SHARED MAP: Layer opacity: \(rasterLayerCheck.rasterOpacity?.constantValue ?? "NIL")")
                print("✅ SHARED MAP: Layer visible: \(rasterLayerCheck.isVisible)")
            }
        } else {
            print("❌ SHARED MAP: Failed to add layer \(layerId)")
        }
        
        print("🗺️ SHARED MAP: Floor \(floor) layer creation complete")
        
        // No artificial delay - MapLibre handles async loading internally
    }
    
    /// Move the shared map to be visible in the main map container
    func attachToMainMapContainer(_ mainContainer: UIView) {
        guard let sharedMapView = sharedMapView,
              let sharedMapContainer = sharedMapContainer else {
            print("❌ Shared map not ready for attachment")
            return
        }
        
        // Remove from off-screen position
        sharedMapContainer.removeFromSuperview()
        
        // Set up autoresizing for dynamic layout
        sharedMapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        // Add to main container first
        mainContainer.addSubview(sharedMapView)
        
        // Use constraints for proper SwiftUI integration instead of frame
        sharedMapView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            sharedMapView.topAnchor.constraint(equalTo: mainContainer.topAnchor),
            sharedMapView.leadingAnchor.constraint(equalTo: mainContainer.leadingAnchor),
            sharedMapView.trailingAnchor.constraint(equalTo: mainContainer.trailingAnchor),
            sharedMapView.bottomAnchor.constraint(equalTo: mainContainer.bottomAnchor)
        ])
        
        print("✅ Shared map attached to main container with constraints - instant display!")
        
        // DIAGNOSTIC: Verify actual state after attachment
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            print("🔥 POST-ATTACHMENT DIAGNOSTIC (1 second later):")
            print("🔥   - SharedMap frame: \(sharedMapView.frame)")
            print("🔥   - SharedMap bounds: \(sharedMapView.bounds)")
            print("🔥   - SharedMap center: \(sharedMapView.centerCoordinate)")
            print("🔥   - SharedMap zoom: \(sharedMapView.zoomLevel)")
            print("🔥   - SharedMap superview: \(sharedMapView.superview != nil ? "EXISTS" : "NIL")")
            print("🔥   - SharedMap hidden: \(sharedMapView.isHidden)")
            print("🔥   - SharedMap alpha: \(sharedMapView.alpha)")
            print("🔥   - MainContainer frame: \(mainContainer.frame)")
            print("🔥   - MainContainer bounds: \(mainContainer.bounds)")
            print("🔥   - MainContainer hidden: \(mainContainer.isHidden)")
            print("🔥   - MainContainer alpha: \(mainContainer.alpha)")
            
            if let style = sharedMapView.style {
                print("🔥   - Style layers: \(style.layers.count)")
                print("🔥   - Style sources: \(style.sources.count)")
                
                // Check each floor layer state
                for floor in 0...3 {
                    let layerId = "osrs-layer-\(floor)"
                    if let layer = style.layer(withIdentifier: layerId) as? MLNRasterStyleLayer {
                        let opacity = layer.rasterOpacity?.constantValue as? Double ?? -1
                        print("🔥   - Floor \(floor) layer: opacity=\(opacity), visible=\(layer.isVisible)")
                    } else {
                        print("🔥   - Floor \(floor) layer: NOT FOUND")
                    }
                }
            } else {
                print("🔥   - Style: NIL")
            }
            
            // DEEPER BLACK SCREEN DIAGNOSTICS
            print("🔥 BLACK SCREEN DIAGNOSTICS:")
            
            // Check rendering context
            let layer = sharedMapView.layer
            print("🔥   - Layer opacity: \(layer.opacity)")
            print("🔥   - Layer hidden: \(layer.isHidden)")
            print("🔥   - Layer masksToBounds: \(layer.masksToBounds)")
            print("🔥   - Layer contents: \(layer.contents != nil ? "HAS_CONTENT" : "NIL")")
            print("🔥   - Layer sublayers: \(layer.sublayers?.count ?? 0)")
            
            // Check MapLibre internal state
            print("🔥   - MapView userLocationVisible: \(sharedMapView.showsUserLocation)")
            print("🔥   - MapView allowsScrolling: \(sharedMapView.allowsScrolling)")
            print("🔥   - MapView allowsZooming: \(sharedMapView.allowsZooming)")
            
            // Check tile loading state
            if let style = sharedMapView.style {
                for source in style.sources {
                    if let rasterSource = source as? MLNRasterTileSource {
                        print("🔥   - RasterSource \(source.identifier): \(rasterSource.configurationURL?.absoluteString ?? "NO_URL")")
                    }
                }
                
                // Force tile reload
                print("🔥   - Forcing style reload attempt...")
                let currentCenter = sharedMapView.centerCoordinate
                let currentZoom = sharedMapView.zoomLevel
                sharedMapView.setCenter(currentCenter, zoomLevel: currentZoom, animated: false)
            }
            
            // Check if MapView is actually drawing
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                print("🔥 RENDER STATE CHECK (0.5s later):")
                
                // Take a snapshot to see if anything renders
                let renderer = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 100))
                let snapshot = renderer.image { context in
                    sharedMapView.drawHierarchy(in: CGRect(x: 0, y: 0, width: 100, height: 100), afterScreenUpdates: true)
                }
                
                // Analyze snapshot
                let cgImage = snapshot.cgImage
                let dataProvider = cgImage?.dataProvider
                let data = dataProvider?.data
                let buffer = CFDataGetBytePtr(data)
                
                var isBlack = true
                if let buffer = buffer {
                    // Check first 100 pixels for non-black color
                    for i in 0..<400 { // 100 pixels * 4 bytes each
                        if buffer[i] > 10 { // Non-black threshold
                            isBlack = false
                            break
                        }
                    }
                }
                
                print("🔥   - Snapshot is black: \(isBlack)")
                print("🔥   - Snapshot size: \(snapshot.size)")
                
                if isBlack {
                    print("🔥 CRITICAL: MapView is rendering BLACK despite all metrics being correct!")
                    print("🔥 This suggests:")
                    print("🔥   1. Tile data corruption")
                    print("🔥   2. MapLibre GPU context issue") 
                    print("🔥   3. Off-screen to on-screen context transfer failure")
                    print("🔥   4. MBTiles URL loading failure")
                } else {
                    print("🔥 MapView IS rendering content - black screen must be elsewhere!")
                    print("🔥 CRITICAL: Gestures work but tiles are black - TILE LOADING ISSUE!")
                    
                    // Investigate tile-specific problems
                    if let style = sharedMapView.style {
                        print("🔥 TILE DIAGNOSTICS:")
                        print("🔥 Style has \(style.layers.count) layers total")
                        print("🔥 Style has \(style.sources.count) sources total")
                        
                        // List ALL layers and sources first
                        print("🔥 ALL LAYERS:")
                        for (index, layer) in style.layers.enumerated() {
                            print("🔥   [\(index)] \(layer.identifier) (type: \(type(of: layer)))")
                        }
                        
                        print("🔥 ALL SOURCES:")
                        for (index, source) in style.sources.enumerated() {
                            print("🔥   [\(index)] \(source.identifier) (type: \(type(of: source)))")
                        }
                        
                        print("🔥 LOOKING FOR OSRS LAYERS/SOURCES:")
                        for floor in 0...3 {
                            let sourceId = "osrs-source-\(floor)"
                            let layerId = "osrs-layer-\(floor)"
                            
                            if let source = style.source(withIdentifier: sourceId) as? MLNRasterTileSource {
                                print("🔥   Floor \(floor) source:")
                                print("🔥     - URL: \(source.configurationURL?.absoluteString ?? "NIL")")
                                print("🔥     - Identifier: \(source.identifier)")
                                
                                // Check if URL is accessible
                                if let url = source.configurationURL {
                                    let urlString = url.absoluteString
                                    if urlString.hasPrefix("mbtiles://") {
                                        let filePath = String(urlString.dropFirst(10)) // Remove "mbtiles://"
                                        let fileExists = FileManager.default.fileExists(atPath: filePath)
                                        print("🔥     - File exists: \(fileExists)")
                                        
                                        if fileExists {
                                            do {
                                                let attributes = try FileManager.default.attributesOfItem(atPath: filePath)
                                                let fileSize = attributes[.size] as? UInt64 ?? 0
                                                print("🔥     - File size: \(fileSize) bytes")
                                                
                                                if fileSize == 0 {
                                                    print("🔥     - ❌ PROBLEM: MBTiles file is empty!")
                                                }
                                            } catch {
                                                print("🔥     - ❌ PROBLEM: Cannot read file attributes: \(error)")
                                            }
                                        } else {
                                            print("🔥     - ❌ PROBLEM: MBTiles file missing!")
                                        }
                                    }
                                }
                            } else {
                                print("🔥   Floor \(floor) source: NOT FOUND")
                            }
                            
                            if let layer = style.layer(withIdentifier: layerId) as? MLNRasterStyleLayer {
                                let opacity = layer.rasterOpacity?.constantValue as? Double ?? -1
                                print("🔥   Floor \(floor) layer:")
                                print("🔥     - Opacity: \(opacity)")
                                print("🔥     - Visible: \(layer.isVisible)")
                                print("🔥     - Source ID: \(layer.sourceIdentifier ?? "NIL")")
                                print("🔥     - Min zoom: \(layer.minimumZoomLevel)")
                                print("🔥     - Max zoom: \(layer.maximumZoomLevel)")
                                
                                if opacity == 0.0 && floor == 0 {
                                    print("🔥     - ❌ PROBLEM: Floor 0 has opacity 0 - should be 1!")
                                }
                            } else {
                                print("🔥   Floor \(floor) layer: NOT FOUND")
                            }
                        }
                        
                        // Check current zoom level vs layer zoom ranges
                        let currentZoom = sharedMapView.zoomLevel
                        print("🔥 Current zoom: \(currentZoom)")
                        
                        if currentZoom < 1.0 || currentZoom > 12.0 {
                            print("🔥 ❌ PROBLEM: Zoom level \(currentZoom) outside layer range (1-12)!")
                        }
                        
                        // Check coordinate bounds
                        let center = sharedMapView.centerCoordinate
                        print("🔥 Current center: (\(center.latitude), \(center.longitude))")
                        
                        // OSRS map bounds check
                        if center.latitude < -85 || center.latitude > 66 || center.longitude < -180 || center.longitude > -90 {
                            print("🔥 ❌ PROBLEM: Center outside OSRS bounds!")
                        }
                    }
                }
            }
            
            // Force a manual redraw attempt
            sharedMapView.setNeedsDisplay()
            mainContainer.setNeedsDisplay()
        }
    }
    
    /// Update floor opacity in the shared map
    func updateFloor(_ floor: Int) {
        guard let style = sharedMapView?.style else { return }
        
        for floorIndex in 0...3 {
            let layerId = "osrs-layer-\(floorIndex)"
            
            if let layer = style.layer(withIdentifier: layerId) as? MLNRasterStyleLayer {
                let opacity: Double = {
                    if floorIndex == floor {
                        return 1.0  // Target floor: full opacity
                    } else if floorIndex == 0 && floor > 0 {
                        return 0.5  // Ground floor underlay
                    } else {
                        return 0.0  // Other floors: invisible but still rendered
                    }
                }()
                
                layer.rasterOpacity = NSExpression(forConstantValue: opacity)
            }
        }
    }
    
    /// Update progress
    private func updateProgress(_ progress: Double, _ status: String) async {
        await MainActor.run {
            preloadingProgress = progress
        }
        print("🗺️ Shared Map: \(Int(progress * 100))% - \(status)")
    }
    
    /// Check if shared map is ready
    var isMapReady: Bool {
        return mapPreloaded && allLayersReady && sharedMapView != nil
    }
    
    /// Get status summary
    var statusSummary: String {
        if isMapReady {
            return "✅ Shared map ready with all floors"
        } else if isPreloadingMap {
            return "🔄 Creating shared map... \(Int(preloadingProgress * 100))%"
        } else {
            return "⏸️ Not started"
        }
    }
}

// MARK: - MLNMapViewDelegate
extension osrsBackgroundMapPreloader: MLNMapViewDelegate {
    nonisolated func mapView(_ mapView: MLNMapView, didFinishLoading style: MLNStyle) {
        print("🗺️ SHARED MAP: Style loaded - ready for layer creation")
        print("🗺️ SHARED MAP: MapView bounds: \(mapView.bounds)")
        print("🗺️ SHARED MAP: MapView frame: \(mapView.frame)")
        print("🗺️ SHARED MAP: MapView isHidden: \(mapView.isHidden)")
        print("🗺️ SHARED MAP: MapView alpha: \(mapView.alpha)")
        print("🗺️ SHARED MAP: MapView superview: \(mapView.superview != nil ? "EXISTS" : "NIL")")
        print("🗺️ SHARED MAP: Style layers count: \(style.layers.count)")
        print("🗺️ SHARED MAP: Style sources count: \(style.sources.count)")
        
        // Log all layers and sources
        for layer in style.layers {
            print("🗺️ SHARED MAP: Layer \(layer.identifier) (type: \(type(of: layer)))")
        }
        
        for source in style.sources {
            print("🗺️ SHARED MAP: Source \(source.identifier) (type: \(type(of: source)))")
        }
    }
    
    /// Restrict camera movement so visible area doesn't extend beyond OSRS map content  
    nonisolated func mapView(_ mapView: MLNMapView, shouldChangeFrom oldCamera: MLNMapCamera, to newCamera: MLNMapCamera) -> Bool {
        // OSRS map content bounds based on actual 12800x45568 pixel image at 4 pixels/game unit
        let gameMinX = 1024.0
        let gameMaxX = gameMinX + (12800.0 / 4.0) // = 4224
        let gameMaxY = 12608.0 
        let gameMinY = gameMaxY - (45568.0 / 4.0) // = 1216
        
        // Convert corner coordinates to lat/lng
        let topLeft = gameToLatLng(gameX: gameMinX, gameY: gameMinY)     // Game Y=1216 (top)
        let topRight = gameToLatLng(gameX: gameMaxX, gameY: gameMinY)    // Game Y=1216 (top)
        let bottomLeft = gameToLatLng(gameX: gameMinX, gameY: gameMaxY)  // Game Y=12608 (bottom)
        let bottomRight = gameToLatLng(gameX: gameMaxX, gameY: gameMaxY) // Game Y=12608 (bottom)
        
        // Find actual min/max bounds (coordinate system may have inversions)
        let minLat = min(topLeft.latitude, topRight.latitude, bottomLeft.latitude, bottomRight.latitude)
        let maxLat = max(topLeft.latitude, topRight.latitude, bottomLeft.latitude, bottomRight.latitude)
        let minLon = min(topLeft.longitude, topRight.longitude, bottomLeft.longitude, bottomRight.longitude)
        let maxLon = max(topLeft.longitude, topRight.longitude, bottomLeft.longitude, bottomRight.longitude)
        
        // Calculate reasonable buffer (much smaller than before)
        let mapLatRange = maxLat - minLat
        let mapLonRange = maxLon - minLon
        let latBuffer = mapLatRange * 0.3  // 30% buffer for screen area
        let lonBuffer = mapLonRange * 0.3
        
        let center = newCamera.centerCoordinate
        let withinLatBounds = center.latitude >= (minLat - latBuffer) && center.latitude <= (maxLat + latBuffer)
        let withinLonBounds = center.longitude >= (minLon - lonBuffer) && center.longitude <= (maxLon + lonBuffer)
        
        let isWithinBounds = withinLatBounds && withinLonBounds
        
        if !isWithinBounds {
            print("🚫 Pan restricted: Camera center outside OSRS content area")
            print("🚫   - Center: (\(center.latitude), \(center.longitude))")
            print("🚫   - OSRS bounds: lat (\(minLat) to \(maxLat)), lon (\(minLon) to \(maxLon))")
            print("🚫   - With buffer: lat (\(minLat - latBuffer) to \(maxLat + latBuffer)), lon (\(minLon - lonBuffer) to \(maxLon + lonBuffer))")
        }
        
        return isWithinBounds
    }
    
    /// Convert OSRS game coordinates to geographical coordinates for MapLibre
    private nonisolated func gameToLatLng(gameX: Double, gameY: Double) -> CLLocationCoordinate2D {
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
}