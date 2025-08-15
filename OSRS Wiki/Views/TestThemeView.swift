//
//  TestThemeView.swift
//  OSRS Wiki
//
//  Created on iOS theming testing session
//  Simple view to test theming system
//

import SwiftUI

struct TestThemeView: View {
    @StateObject private var themeManager = OSRSThemeManager()
    
    var body: some View {
        VStack(spacing: 20) {
            Text("OSRS Theme Test")
                .font(.largeTitle)
                .foregroundStyle(.osrsTextPrimary)
            
            Text("Primary Text")
                .foregroundStyle(.osrsPrimary)
            
            Text("Secondary Text")
                .foregroundStyle(.osrsTextSecondary)
            
            Text("Accent Color")
                .foregroundStyle(.osrsAccent)
            
            Button("Test Button") {
                // Test action
            }
            .foregroundStyle(.osrsOnPrimary)
            .padding()
            .background(.osrsPrimary)
            .cornerRadius(8)
            
            HStack {
                ForEach(OSRSThemeSelection.allCases, id: \.self) { theme in
                    Button(theme.displayName) {
                        themeManager.setTheme(theme)
                    }
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(themeManager.selectedTheme == theme ? .osrsAccent : .osrsSurface)
                    .foregroundStyle(themeManager.selectedTheme == theme ? .osrsOnPrimary : .osrsTextPrimary)
                    .cornerRadius(4)
                }
            }
        }
        .padding()
        .background(.osrsBackground)
        .environment(\.osrsTheme, themeManager.currentTheme)
        .environmentObject(themeManager)
    }
}

#if DEBUG
struct TestThemeView_Previews: PreviewProvider {
    static var previews: some View {
        TestThemeView()
    }
}
#endif