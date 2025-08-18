//
//  OSRS_WikiApp.swift
//  OSRS Wiki
//
//  Created by Osamu Miyawaki on 7/29/25.
//

import SwiftUI

@main
struct osrswikiApp: App {
    init() {
        // Register custom fonts when app starts
        print("🚀 App starting...")
        osrsFontRegistrar.registerFonts()
        print("✅ Font registration completed")
    }
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
    }
}
