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
    @State private var isMapReady: Bool = false
    
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
        ZStack {
            // MapLibre Native view
            osrsMapLibreMapView(
                currentFloor: $currentFloor,
                isMapReady: $isMapReady
            )
            .ignoresSafeArea(.all, edges: .top)
            
            // Simple loading overlay that appears only briefly when map is not ready
            if !isMapReady {
                VStack {
                    Spacer()
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.2)
                            .tint(Color(osrsTheme.mapControlTextColor))
                        Text("Loading map...")
                            .foregroundColor(Color(osrsTheme.mapControlTextColor))
                            .font(.system(size: 16, weight: .medium))
                    }
                    .padding(20)
                    .background(Color(osrsTheme.mapControlBackgroundColor).opacity(0.8))
                    .cornerRadius(12)
                    Spacer()
                }
                .background(Color(osrsTheme.mapControlBackgroundColor).opacity(0.3))
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.3), value: isMapReady)
            }
            
            // Floor controls overlay aligned with compass
            VStack {
                HStack(alignment: .top) {
                    osrsFloorControlsView(
                        currentFloor: $currentFloor,
                        maxFloor: maxFloor
                    )
                    .padding(.leading, 8) // Match compass right margin (8pt from screen edge)
                    .padding(.top, 8) // Match compass top margin
                    
                    Spacer()
                }
                
                Spacer()
            }
        }
        .navigationBarHidden(true)
        .background(.osrsBackground)
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
    
    // Fixed compass dimensions for alignment
    private let compassWidth: CGFloat = 40
    private let compassHeight: CGFloat = 40
    
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
                    .frame(width: compassWidth, height: compassHeight)
                    .foregroundColor(Color(osrsTheme.mapControlTextColor))
                    .background(Color.clear)
            }
            .disabled(currentFloor >= maxFloor)
            .opacity(currentFloor >= maxFloor ? 0.4 : 1.0)
            
            // Floor number display
            Text("\(currentFloor)")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color(osrsTheme.mapControlTextColor))
                .frame(width: compassWidth, height: 28)
                .padding(.vertical, 4)
            
            // Down arrow button
            Button(action: {
                if currentFloor > 0 {
                    currentFloor -= 1
                }
            }) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 16, weight: .medium))
                    .frame(width: compassWidth, height: compassHeight)
                    .foregroundColor(Color(osrsTheme.mapControlTextColor))
                    .background(Color.clear)
            }
            .disabled(currentFloor <= 0)
            .opacity(currentFloor <= 0 ? 0.4 : 1.0)
        }
        .padding(4)
        .frame(width: compassWidth + 8) // Match compass width (40px + 8px padding)
        .background(Color(osrsTheme.mapControlBackgroundColor))
        .clipShape(Capsule()) // Perfect semicircles at top and bottom
        .shadow(radius: 4)
    }
}


struct osrsMapLibreMapView: UIViewRepresentable {
    @Binding var currentFloor: Int
    @Binding var isMapReady: Bool
    
    func makeUIView(context: Context) -> UIView {
        // Create container view
        let containerView = UIView()
        containerView.backgroundColor = .black
        
        // Check if shared map is ready
        if osrsBackgroundMapPreloader.shared.isMapReady {
            print("✅ Using shared map instance - instant display!")
            print("🔥 REAL MAP TAB: About to attach shared map to SwiftUI container")
            print("🔥 REAL MAP TAB: Container frame: \(containerView.frame)")
            print("🔥 REAL MAP TAB: Container bounds: \(containerView.bounds)")
            print("🔥 REAL MAP TAB: Container hidden: \(containerView.isHidden)")
            print("🔥 REAL MAP TAB: Container alpha: \(containerView.alpha)")
            
            osrsBackgroundMapPreloader.shared.attachToMainMapContainer(containerView)
            
            // Set up coordinator to handle floor updates
            context.coordinator.setupWithSharedMap()
            
            // Mark as ready immediately
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isMapReady = true
            }
            
            // Additional verification after attachment in real app
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                print("🔥 REAL MAP TAB VERIFICATION (2s after attachment):")
                print("🔥   - Container subviews: \(containerView.subviews.count)")
                
                if let mapView = containerView.subviews.first {
                    print("🔥   - MapView frame: \(mapView.frame)")
                    print("🔥   - MapView bounds: \(mapView.bounds)")
                    print("🔥   - MapView hidden: \(mapView.isHidden)")
                    print("🔥   - MapView alpha: \(mapView.alpha)")
                    print("🔥   - MapView in window: \(mapView.window != nil)")
                    
                    if let mlnMapView = mapView as? MLNMapView {
                        // Take actual screenshot of real map tab
                        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 100))
                        let realTabSnapshot = renderer.image { context in
                            mlnMapView.drawHierarchy(in: CGRect(x: 0, y: 0, width: 100, height: 100), afterScreenUpdates: true)
                        }
                        
                        // Analyze real tab snapshot
                        let cgImage = realTabSnapshot.cgImage
                        let dataProvider = cgImage?.dataProvider
                        let data = dataProvider?.data
                        let buffer = CFDataGetBytePtr(data)
                        
                        var isBlack = true
                        if let buffer = buffer {
                            for i in 0..<400 {
                                if buffer[i] > 10 {
                                    isBlack = false
                                    break
                                }
                            }
                        }
                        
                        print("🔥   - REAL MAP TAB snapshot is black: \(isBlack)")
                        
                        if isBlack {
                            print("🔥 SMOKING GUN: Real Map tab IS black - user is correct!")
                            print("🔥 Issue confirmed: Attachment works but rendering fails")
                        } else {
                            print("🔥 Map tab IS rendering - black screen must be UI hierarchy issue")
                        }
                    }
                }
            }
            
        } else {
            print("⚠️ Shared map not ready - will show loading state")
            
            // Show loading state and wait for shared map to be ready
            let loadingLabel = UILabel()
            loadingLabel.text = "Preparing map..."
            loadingLabel.textColor = .white
            loadingLabel.textAlignment = .center
            loadingLabel.translatesAutoresizingMaskIntoConstraints = false
            
            containerView.addSubview(loadingLabel)
            NSLayoutConstraint.activate([
                loadingLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
                loadingLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor)
            ])
            
            // Check periodically for shared map to be ready
            context.coordinator.waitForSharedMap(containerView: containerView) {
                DispatchQueue.main.async {
                    context.coordinator.isMapReady = true
                }
            }
        }
        
        return containerView
    }
    
    func updateUIView(_ containerView: UIView, context: Context) {
        // Update floor in shared map
        Task { @MainActor in
            context.coordinator.updateFloor(currentFloor)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject {
        var parent: osrsMapLibreMapView
        var isMapReady: Bool = false
        
        init(_ parent: osrsMapLibreMapView) {
            self.parent = parent
            super.init()
        }
        
        /// Set up coordinator to work with shared map
        func setupWithSharedMap() {
            print("✅ Coordinator setup with shared map instance")
            isMapReady = true
            parent.isMapReady = true
        }
        
        /// Wait for shared map to be ready and attach it
        @MainActor
        func waitForSharedMap(containerView: UIView, completion: @escaping () -> Void) {
            print("⏳ Waiting for shared map to be ready...")
            
            // Check every 100ms for up to 10 seconds
            var attempts = 0
            let maxAttempts = 100
            
            func checkSharedMap() {
                attempts += 1
                
                if osrsBackgroundMapPreloader.shared.isMapReady {
                    print("✅ Shared map ready - attaching to container")
                    
                    // Clear loading state
                    containerView.subviews.forEach { $0.removeFromSuperview() }
                    
                    // Attach shared map
                    osrsBackgroundMapPreloader.shared.attachToMainMapContainer(containerView)
                    
                    // Mark as ready
                    isMapReady = true
                    parent.isMapReady = true
                    completion()
                    
                } else if attempts < maxAttempts {
                    // Keep checking
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        checkSharedMap()
                    }
                } else {
                    print("⚠️ Shared map not ready after timeout - showing error")
                    
                    let errorLabel = UILabel()
                    errorLabel.text = "Map loading failed"
                    errorLabel.textColor = .red
                    errorLabel.textAlignment = .center
                    errorLabel.translatesAutoresizingMaskIntoConstraints = false
                    
                    containerView.subviews.forEach { $0.removeFromSuperview() }
                    containerView.addSubview(errorLabel)
                    NSLayoutConstraint.activate([
                        errorLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
                        errorLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor)
                    ])
                }
            }
            
            // Start checking
            checkSharedMap()
        }
        
        /// Update floor in shared map
        @MainActor
        func updateFloor(_ floor: Int) {
            guard isMapReady else {
                print("⚠️ Map not ready yet for floor update")
                return
            }
            
            print("🔄 Updating shared map to floor \(floor)")
            osrsBackgroundMapPreloader.shared.updateFloor(floor)
        }
    }
}

#Preview {
    osrsMapLibreView()
        .environmentObject(AppState())
        .environmentObject(osrsThemeManager.preview)
        .environment(\.osrsTheme, osrsLightTheme())
}