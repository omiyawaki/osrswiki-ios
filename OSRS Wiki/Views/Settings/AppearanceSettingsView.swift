//
//  AppearanceSettingsView.swift
//  OSRS Wiki
//
//  Created on iOS development session
//  Updated for modern OSRS theme system integration
//

import SwiftUI

struct AppearanceSettingsView: View {
    @EnvironmentObject var themeManager: OSRSThemeManager
    @Environment(\.osrsTheme) var osrsTheme
    @StateObject private var transitionManager = OSRSThemeTransitionManager()
    
    var body: some View {
        List {
            Section {
                ForEach(OSRSThemeSelection.allCases, id: \.self) { themeSelection in
                    Button(action: {
                        transitionManager.animateThemeTransition {
                            themeManager.setTheme(themeSelection)
                        }
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(themeSelection.displayName)
                                    .font(.body)
                                    .foregroundStyle(.osrsOnSurface)
                                
                                Text(themeSelection.description)
                                    .font(.caption)
                                    .foregroundStyle(.osrsOnSurfaceVariant)
                                    .multilineTextAlignment(.leading)
                            }
                            
                            Spacer()
                            
                            if themeManager.selectedTheme == themeSelection {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.osrsPrimary)
                                    .font(.body.weight(.semibold))
                                    .scaleEffect(transitionManager.isTransitioning ? 1.2 : 1.0)
                                    .animation(.spring(response: 0.5, dampingFraction: 0.6), 
                                             value: transitionManager.isTransitioning)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .osrsThemeTransition(transitionManager, animationIndex: themeSelection.hashValue)
                }
            } header: {
                Text("Theme Selection")
                    .foregroundStyle(.osrsOnSurfaceVariant)
            }
            
            Section {
                OSRSThemePreviewCard(theme: themeManager.currentTheme)
            } header: {
                Text("Current Theme Preview")
                    .foregroundStyle(.osrsOnSurfaceVariant)
            }
            
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("OSRS Theming")
                        .font(.headline)
                        .foregroundStyle(.osrsOnSurface)
                    
                    Text("The OSRS Wiki app uses authentic Old School RuneScape colors and styling to create an immersive experience that matches the game's aesthetic.")
                        .font(.caption)
                        .foregroundStyle(.osrsOnSurfaceVariant)
                    
                    Text("• Automatic: Switches between OSRS Light and OSRS Dark based on your system setting")
                        .font(.caption2)
                        .foregroundStyle(.osrsOnSurfaceVariant)
                    
                    Text("• OSRS Light: Parchment-inspired backgrounds with warm gold accents")
                        .font(.caption2)
                        .foregroundStyle(.osrsOnSurfaceVariant)
                    
                    Text("• OSRS Dark: Aged parchment with high contrast for night reading")
                        .font(.caption2)
                        .foregroundStyle(.osrsOnSurfaceVariant)
                }
                .padding(.vertical, 4)
            } header: {
                Text("About OSRS Theming")
                    .foregroundStyle(.osrsOnSurfaceVariant)
            }
        }
        .listStyle(InsetGroupedListStyle())
        .navigationTitle("Appearance")
        .navigationBarTitleDisplayMode(.inline)
        .background(.osrsBackground)
        .scrollContentBackground(.hidden)
        .overlay(alignment: .bottom) {
            OSRSThemeTransitionIndicator(isTransitioning: transitionManager.isTransitioning)
                .padding(.bottom, 20)
        }
    }
}

struct OSRSThemePreviewCard: View {
    let theme: any OSRSThemeProtocol
    
    var body: some View {
        VStack(spacing: 12) {
            Text("Preview")
                .font(.headline)
                .foregroundStyle(.osrsOnSurface)
            
            // Color swatches showing theme colors
            HStack(spacing: 12) {
                VStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(theme.primary))
                        .frame(width: 50, height: 30)
                    Text("Primary")
                        .font(.caption2)
                        .foregroundStyle(.osrsOnSurfaceVariant)
                }
                
                VStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(theme.surface))
                        .frame(width: 50, height: 30)
                    Text("Surface")
                        .font(.caption2)
                        .foregroundStyle(.osrsOnSurfaceVariant)
                }
                
                VStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(theme.accent))
                        .frame(width: 50, height: 30)
                    Text("Accent")
                        .font(.caption2)
                        .foregroundStyle(.osrsOnSurfaceVariant)
                }
                
                VStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(theme.background))
                        .frame(width: 50, height: 30)
                    Text("Background")
                        .font(.caption2)
                        .foregroundStyle(.osrsOnSurfaceVariant)
                }
            }
            
            // Sample UI elements
            VStack(spacing: 8) {
                HStack {
                    Text("Sample Article Title")
                        .font(.headline)
                        .foregroundStyle(.osrsOnSurface)
                    Spacer()
                }
                
                HStack {
                    Text("This is how text appears in articles with the current theme.")
                        .font(.body)
                        .foregroundStyle(.osrsOnSurface)
                    Spacer()
                }
                
                HStack {
                    Button("Sample Button") {
                        // Preview only
                    }
                    .foregroundStyle(.osrsOnPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(theme.primary))
                    .cornerRadius(6)
                    
                    Spacer()
                    
                    Text("Secondary text")
                        .font(.caption)
                        .foregroundStyle(.osrsOnSurfaceVariant)
                }
            }
        }
        .padding()
        .background(Color(theme.surface))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(theme.outline), lineWidth: 1)
        )
    }
}

#Preview {
    NavigationStack {
        AppearanceSettingsView()
            .environmentObject(OSRSThemeManager.preview)
            .environment(\.osrsTheme, OSRSLightTheme())
    }
}

#Preview("Dark Theme") {
    NavigationStack {
        AppearanceSettingsView()
            .environmentObject(OSRSThemeManager.previewDark)
            .environment(\.osrsTheme, OSRSDarkTheme())
    }
    .preferredColorScheme(.dark)
}

