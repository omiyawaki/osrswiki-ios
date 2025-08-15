//
//  MapView.swift
//  OSRS Wiki
//
//  Created on iOS development session
//

import SwiftUI

struct MapView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = MapViewModel()
    
    var body: some View {
        NavigationStack(path: $appState.navigationPath) {
            ZStack {
                if viewModel.isLoading {
                    ProgressView("Loading map...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView([.horizontal, .vertical]) {
                        MapImageView(mapData: viewModel.currentMap)
                            .frame(width: viewModel.mapSize.width, height: viewModel.mapSize.height)
                    }
                    .clipped()
                }
                
                VStack {
                    HStack {
                        Spacer()
                        
                        MapControlsView(viewModel: viewModel)
                            .padding()
                    }
                    
                    Spacer()
                }
            }
            .navigationTitle("OSRS Map")
            .navigationBarTitleDisplayMode(.inline)
            .background(appState.currentTheme.backgroundColor)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        ForEach(MapType.allCases, id: \.self) { mapType in
                            Button(mapType.displayName) {
                                viewModel.switchToMap(mapType)
                            }
                        }
                    } label: {
                        Image(systemName: "map")
                    }
                }
            }
        }
        .task {
            await viewModel.loadDefaultMap()
        }
    }
}

struct MapImageView: View {
    let mapData: MapData?
    
    var body: some View {
        if let mapData = mapData {
            AsyncImage(url: mapData.imageUrl) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } placeholder: {
                Rectangle()
                    .fill(Color(.systemGray5))
                    .overlay(
                        ProgressView()
                    )
            }
        } else {
            EmptyStateView(
                iconName: "map",
                title: "Map Unavailable",
                subtitle: "Unable to load map data"
            )
        }
    }
}

struct MapControlsView: View {
    @ObservedObject var viewModel: MapViewModel
    
    var body: some View {
        VStack(spacing: 8) {
            Button(action: viewModel.zoomIn) {
                Image(systemName: "plus")
                    .font(.title2)
                    .foregroundColor(.primary)
                    .frame(width: 44, height: 44)
                    .background(Color(.systemBackground))
                    .clipShape(Circle())
                    .shadow(radius: 2)
            }
            
            Button(action: viewModel.zoomOut) {
                Image(systemName: "minus")
                    .font(.title2)
                    .foregroundColor(.primary)
                    .frame(width: 44, height: 44)
                    .background(Color(.systemBackground))
                    .clipShape(Circle())
                    .shadow(radius: 2)
            }
            
            Button(action: viewModel.resetZoom) {
                Image(systemName: "arrow.clockwise")
                    .font(.title2)
                    .foregroundColor(.primary)
                    .frame(width: 44, height: 44)
                    .background(Color(.systemBackground))
                    .clipShape(Circle())
                    .shadow(radius: 2)
            }
        }
    }
}

#Preview {
    MapView()
        .environmentObject(AppState())
}