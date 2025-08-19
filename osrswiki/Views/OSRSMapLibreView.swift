//
//  osrsMapLibreView.swift
//  OSRS Wiki
//
//  MapLibre Native implementation with MBTiles support for OSRS game maps
//

import SwiftUI
import MapLibre
import Foundation
import CoreLocation

struct osrsMapLibreView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: osrsThemeManager
    @Environment(\.osrsTheme) var osrsTheme
    @State private var currentFloor: Int = 0
    
    private let maxFloor = 3
    
    // Constants ported from Android
    struct MapConstants {
        static let gameCoordScale = 4.0
        static let gameMinX = 1024.0
        static let gameMaxY = 12608.0
        static let canvasSize = 65536.0
        static let defaultLat = -25.2023457171692
        static let defaultLon = -131.44071698586012
        static let defaultZoom = 7.3414426741929
    }
    
    var body: some View {
        NavigationStack(path: $appState.navigationPath) {
            ZStack {
                // MapLibre Native view
                osrsMapLibreMapView(currentFloor: $currentFloor)
                    .ignoresSafeArea(.all, edges: .top)
                
                // Floor controls and compass overlay
                VStack {
                    HStack(alignment: .top) {
                        osrsFloorControlsView(
                            currentFloor: $currentFloor,
                            maxFloor: maxFloor
                        )
                        .padding(.leading, 16)
                        .padding(.top, 60) // Position where title used to be
                        
                        Spacer()
                        
                        osrsCompassView()
                            .padding(.trailing, 16)
                            .padding(.top, 60) // Align with floor controls
                    }
                    
                    Spacer()
                }
            }
            .navigationBarHidden(true)
            .background(.osrsBackground)
        }
    }
    
    // Coordinate conversion function ported from Android
    static func gameToLatLng(gx: Double, gy: Double) -> CLLocationCoordinate2D {
        let px = (gx - MapConstants.gameMinX) * MapConstants.gameCoordScale
        let py = (MapConstants.gameMaxY - gy) * MapConstants.gameCoordScale
        let nx = px / MapConstants.canvasSize
        let ny = py / MapConstants.canvasSize
        let lon = -180.0 + nx * 360.0
        let lat = (atan(sinh(.pi * (1.0 - 2.0 * ny))) * 180.0) / .pi
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}

struct osrsFloorControlsView: View {
    @Binding var currentFloor: Int
    let maxFloor: Int
    @Environment(\.osrsTheme) var osrsTheme
    
    var body: some View {
        VStack(spacing: 4) {
            // Up arrow button
            Button(action: {
                if currentFloor < maxFloor {
                    currentFloor += 1
                }
            }) {
                Image(systemName: "chevron.up")
                    .font(.system(size: 16, weight: .medium))
                    .frame(width: 40, height: 40)
                    .foregroundColor(osrsTheme.onSurface)
                    .background(Color.clear)
            }
            .disabled(currentFloor >= maxFloor)
            .opacity(currentFloor >= maxFloor ? 0.5 : 1.0)
            
            // Floor number display
            Text("\(currentFloor)")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(osrsTheme.onSurface)
                .frame(width: 40, height: 28)
                .padding(.vertical, 4)
            
            // Down arrow button
            Button(action: {
                if currentFloor > 0 {
                    currentFloor -= 1
                }
            }) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 16, weight: .medium))
                    .frame(width: 40, height: 40)
                    .foregroundColor(osrsTheme.onSurface)
                    .background(Color.clear)
            }
            .disabled(currentFloor <= 0)
            .opacity(currentFloor <= 0 ? 0.5 : 1.0)
        }
        .padding(4)
        .background(osrsTheme.surface.opacity(0.9))
        .cornerRadius(8)
        .shadow(radius: 4)
    }
}

struct osrsCompassView: View {
    @State private var heading: Double = 0
    @Environment(\.osrsTheme) var osrsTheme
    
    var body: some View {
        Button(action: {
            // Reset rotation to north - this would be implemented with map delegate
        }) {
            ZStack {
                Circle()
                    .fill(osrsTheme.surface.opacity(0.9))
                    .frame(width: 40, height: 40)
                    .shadow(radius: 4)
                
                Image(systemName: "location.north.fill")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(osrsTheme.onSurface)
                    .rotationEffect(.degrees(-heading))
            }
        }
    }
}

struct osrsMapLibreMapView: UIViewRepresentable {
    @Binding var currentFloor: Int
    
    func makeUIView(context: Context) -> MLNMapView {
        let mapView = MLNMapView()
        mapView.delegate = context.coordinator
        
        // Configure MapLibre settings
        mapView.logoView.isHidden = true
        mapView.attributionButton.isHidden = true
        mapView.compassView.isHidden = true
        mapView.showsScale = false
        mapView.allowsRotating = true
        mapView.allowsTilting = false
        
        // Set initial camera position to Lumbridge (game coordinates 3234, 3230)
        let center = CLLocationCoordinate2D(
            latitude: osrsMapLibreView.MapConstants.defaultLat,
            longitude: osrsMapLibreView.MapConstants.defaultLon
        )
        
        mapView.setCenter(center, zoomLevel: osrsMapLibreView.MapConstants.defaultZoom, animated: false)
        
        // Set bounds based on actual MBTiles tile coverage to prevent scrolling outside content
        // Based on zoom level 4 coverage: cols 0-3, rows 4-15
        // This corresponds to the actual area where we have map tiles
        let contentBounds = MLNCoordinateBounds(
            sw: CLLocationCoordinate2D(latitude: -85.051129, longitude: -180.0),    // Southwest corner
            ne: CLLocationCoordinate2D(latitude: 66.513260, longitude: -90.0)      // Northeast corner  
        )
        mapView.setVisibleCoordinateBounds(contentBounds, animated: false)
        
        print("🗺️ Set map bounds - SW: \(contentBounds.sw), NE: \(contentBounds.ne)")
        print("🎯 Initial position (Lumbridge): \(center), zoom: \(osrsMapLibreView.MapConstants.defaultZoom)")
        
        // Set a minimal custom style to prevent loading default remote style
        let customStyleJSON = """
        {
            "version": 8,
            "name": "OSRS Map Style",
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
        
        // Create a temporary file URL for the style
        let tempDirectory = FileManager.default.temporaryDirectory
        let styleURL = tempDirectory.appendingPathComponent("osrs-style.json")
        
        do {
            try customStyleJSON.write(to: styleURL, atomically: true, encoding: .utf8)
            mapView.styleURL = styleURL
            print("✅ Set custom OSRS style")
        } catch {
            print("❌ Failed to write style file: \(error)")
        }
        
        return mapView
    }
    
    func updateUIView(_ mapView: MLNMapView, context: Context) {
        context.coordinator.updateFloor(currentFloor, for: mapView)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MLNMapViewDelegate {
        var parent: osrsMapLibreMapView
        private var currentMapStyle: MLNStyle?
        
        init(_ parent: osrsMapLibreMapView) {
            self.parent = parent
            super.init()
        }
        
        func mapView(_ mapView: MLNMapView, didFinishLoading style: MLNStyle) {
            print("🗺️ MapLibre style loaded successfully")
            currentMapStyle = style
            setupMapStyle(style)
            updateFloor(parent.currentFloor, for: mapView)
            
            // Ensure correct zoom level and position after style loads
            let targetCenter = CLLocationCoordinate2D(
                latitude: osrsMapLibreView.MapConstants.defaultLat,
                longitude: osrsMapLibreView.MapConstants.defaultLon
            )
            
            let camera = MLNMapCamera(
                lookingAtCenter: targetCenter,
                acrossDistance: 1000,
                pitch: 0,
                heading: 0
            )
            
            mapView.setCamera(camera, animated: false)
            mapView.zoomLevel = osrsMapLibreView.MapConstants.defaultZoom
        }
        
        private func setupMapStyle(_ style: MLNStyle) {
            print("⚙️ Setting up OSRS map style")
            
            // Create a simple black background style
            if let backgroundLayer = style.layer(withIdentifier: "background") as? MLNBackgroundStyleLayer {
                backgroundLayer.backgroundColor = NSExpression(forConstantValue: UIColor.black)
            } else {
                let backgroundLayer = MLNBackgroundStyleLayer(identifier: "background")
                backgroundLayer.backgroundColor = NSExpression(forConstantValue: UIColor.black)
                style.addLayer(backgroundLayer)
            }
        }
        
        func updateFloor(_ floor: Int, for mapView: MLNMapView) {
            guard let style = currentMapStyle else {
                print("❌ Style not loaded yet, deferring floor update")
                return
            }
            
            print("🔄 Switching to floor \(floor)")
            
            // Android-style floor switching logic:
            // 1. Target floor shown at 100% opacity
            // 2. If floor > 0, show floor 0 as underlay at 50% opacity
            // 3. Hide all other floors
            
            for floorIndex in 0...3 {
                let layerId = "osrs-layer-\(floorIndex)"
                
                if let layer = style.layer(withIdentifier: layerId) as? MLNRasterStyleLayer {
                    // Layer already exists, just update visibility and opacity
                    if floorIndex == floor {
                        // Target floor: visible at 100% opacity
                        layer.isVisible = true
                        layer.rasterOpacity = NSExpression(forConstantValue: 1.0)
                        print("✅ Floor \(floorIndex): visible at 100%")
                    } else if floorIndex == 0 && floor > 0 {
                        // Ground floor underlay when viewing upper floors
                        layer.isVisible = true
                        layer.rasterOpacity = NSExpression(forConstantValue: 0.5)
                        print("✅ Floor \(floorIndex): visible at 50% (underlay)")
                    } else {
                        // Hide all other floors
                        layer.isVisible = false
                        print("🚫 Floor \(floorIndex): hidden")
                    }
                } else {
                    // Layer doesn't exist yet, create it
                    addFloorLayer(floor: floorIndex, to: style)
                    
                    // Set initial visibility based on floor switching logic
                    if let newLayer = style.layer(withIdentifier: layerId) as? MLNRasterStyleLayer {
                        if floorIndex == floor {
                            newLayer.isVisible = true
                            newLayer.rasterOpacity = NSExpression(forConstantValue: 1.0)
                        } else if floorIndex == 0 && floor > 0 {
                            newLayer.isVisible = true
                            newLayer.rasterOpacity = NSExpression(forConstantValue: 0.5)
                        } else {
                            newLayer.isVisible = false
                        }
                    }
                }
            }
        }
        
        private func addFloorLayer(floor: Int, to style: MLNStyle) {
            print("🏗️ Adding MBTiles layer for floor \(floor)")
            
            let sourceId = "osrs-source-\(floor)"
            let layerId = "osrs-layer-\(floor)"
            let fileName = "map_floor_\(floor)"
            
            // Get MBTiles file path
            guard let mbtilesPath = Bundle.main.path(forResource: fileName, ofType: "mbtiles") else {
                print("❌ MBTiles file not found: \(fileName)")
                return
            }
            
            print("✅ Found MBTiles at: \(mbtilesPath)")
            
            // Create MBTiles source - MapLibre iOS supports mbtiles:// protocol
            let mbtilesURLString = "mbtiles://\(mbtilesPath)"
            
            // Create raster source using the mbtiles URL
            let rasterSource = MLNRasterTileSource(
                identifier: sourceId,
                configurationURL: URL(string: mbtilesURLString)!
            )
            
            style.addSource(rasterSource)
            
            // Create raster layer with nearest-neighbor resampling for crisp, pixelated rendering
            let rasterLayer = MLNRasterStyleLayer(identifier: layerId, source: rasterSource)
            
            // Set raster resampling to nearest neighbor to match Android's crisp rendering
            // This prevents smooth interpolation and maintains the pixelated game art style
            rasterLayer.rasterResamplingMode = NSExpression(forConstantValue: "nearest")
            
            style.addLayer(rasterLayer)
            
            print("✅ Added MBTiles layer for floor \(floor)")
        }
    }
}


#Preview {
    osrsMapLibreView()
        .environmentObject(AppState())
        .environmentObject(osrsThemeManager.preview)
        .environment(\.osrsTheme, osrsLightTheme())
}