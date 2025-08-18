//
//  MapView.swift
//  OSRS Wiki
//
//  MapLibre Native implementation for OSRS map
//

import SwiftUI

struct MapView: View {
    var body: some View {
        osrsMapLibreView()
    }
}

#Preview {
    MapView()
        .environmentObject(AppState())
        .environmentObject(osrsThemeManager.preview)
        .environment(\.osrsTheme, osrsLightTheme())
}