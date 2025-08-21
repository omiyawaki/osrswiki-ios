//
//  AppearanceSettingsView.swift
//  OSRS Wiki
//
//  Complete rewrite to match Android appearance page exactly with visual previews
//

import SwiftUI

struct AppearanceSettingsView: View {
    @EnvironmentObject var themeManager: osrsThemeManager
    @Environment(\.osrsTheme) var osrsTheme
    @ObservedObject private var themePreviewRenderer = osrsThemePreviewRenderer.shared
    @ObservedObject private var tablePreviewRenderer = osrsTablePreviewRenderer.shared
    @ObservedObject private var backgroundPreviewManager = osrsBackgroundPreviewManager.shared
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Theme selection cards (exactly like Android)
                VStack(spacing: 16) {
                    ForEach(osrsThemeSelection.allCases, id: \.self) { themeOption in
                        osrsThemePreviewCard(
                            theme: themeOption,
                            isSelected: themeManager.selectedTheme == themeOption,
                            onSelect: { themeManager.setTheme(themeOption) },
                            previewRenderer: themePreviewRenderer
                        )
                    }
                }
                .padding(.horizontal, 16)
                
                // Collapse tables section (exactly like Android)
                VStack(spacing: 0) {
                    Text("Collapse tables")
                        .font(.title2.weight(.medium))
                        .foregroundStyle(.osrsPrimaryTextColor)
                        .padding(.bottom, 16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    HStack(spacing: 16) {
                        // Expanded preview
                        osrsTablePreviewCard(
                            title: "Expanded",
                            subtitle: "Tables start expanded",
                            isSelected: !themeManager.collapseTables,
                            collapsed: false,
                            onSelect: { themeManager.setCollapseTables(false) },
                            tablePreviewRenderer: tablePreviewRenderer
                        )
                        
                        // Collapsed preview (selected)
                        osrsTablePreviewCard(
                            title: "Collapsed",
                            subtitle: "Tables start collapsed",
                            isSelected: themeManager.collapseTables,
                            collapsed: true,
                            onSelect: { themeManager.setCollapseTables(true) },
                            tablePreviewRenderer: tablePreviewRenderer
                        )
                    }
                }
                .padding(.horizontal, 16)
                
                Spacer(minLength: 50)
            }
            .padding(.top, 20)
        }
        .navigationTitle("Appearance")
        .navigationBarTitleDisplayMode(.inline)
        .background(.osrsBackground)
        .scrollContentBackground(.hidden)
    }
}

/// Theme preview card with actual rendered preview (matches Android exactly)
struct osrsThemePreviewCard: View {
    let theme: osrsThemeSelection
    let isSelected: Bool
    let onSelect: () -> Void
    let previewRenderer: osrsThemePreviewRenderer
    
    @Environment(\.osrsTheme) var osrsTheme
    @ObservedObject private var backgroundPreviewManager = osrsBackgroundPreviewManager.shared
    @State private var previewImage: UIImage? = nil
    
    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 0) {
                // Preview image area (actual rendered preview like Android)
                Group {
                    if let previewImage = previewImage {
                        Image(uiImage: previewImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .onAppear {
                                print("🖼️ SHOWING GENERATED IMAGE for \(theme.rawValue) - size: \(previewImage.size)")
                            }
                    } else {
                        // Loading placeholder - show background generation progress
                        ZStack {
                            Color(osrsTheme.surface)
                            if backgroundPreviewManager.isGeneratingPreviews {
                                VStack(spacing: 8) {
                                    ProgressView(value: backgroundPreviewManager.generationProgress)
                                        .progressViewStyle(LinearProgressViewStyle())
                                        .frame(width: 80)
                                    Text("Generating...")
                                        .font(.caption2)
                                        .foregroundStyle(.osrsPlaceholderColor)
                                }
                            } else {
                                ProgressView()
                                    .scaleEffect(0.5)
                            }
                        }
                        .onAppear {
                            print("🖼️ LOADING PLACEHOLDER for \(theme.rawValue) - background ready: \(backgroundPreviewManager.arePreviewsReady)")
                        }
                    }
                }
                .frame(height: 120)
                .clipped()
                
                // Title and description area
                VStack(spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(theme.displayName)
                                .font(.headline)
                                .foregroundStyle(.osrsPrimaryTextColor)
                            
                            Text(theme.description)
                                .font(.caption)
                                .foregroundStyle(.osrsSecondaryTextColor)
                        }
                        
                        Spacer()
                        
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.osrsPrimary)
                                .font(.title2)
                        }
                    }
                }
                .padding(16)
                .background(Color(osrsTheme.surface))
            }
        }
        .buttonStyle(PlainButtonStyle())
        .background(Color(osrsTheme.surface))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color(osrsTheme.primary) : Color(osrsTheme.outline), lineWidth: isSelected ? 2 : 1)
        )
        .onAppear {
            print("🖼️ ThemePreviewCard: onAppear called for \(theme.rawValue) - background ready: \(backgroundPreviewManager.arePreviewsReady)")
            
            // If background previews are ready, get from cache; otherwise generate individually
            Task {
                if backgroundPreviewManager.arePreviewsReady {
                    print("🖼️ ThemePreviewCard: ⚡ INSTANT ACCESS - Using cached preview for \(theme.rawValue)")
                    // Get cached image directly - no generation needed!
                    if let cachedImage = previewRenderer.getCachedPreview(for: theme) {
                        await MainActor.run {
                            self.previewImage = cachedImage
                            print("🖼️ ThemePreviewCard: ⚡ INSTANT LOAD - Cached preview displayed for \(theme.rawValue)")
                        }
                    } else {
                        print("⚠️ ThemePreviewCard: Cache miss! Generating preview for \(theme.rawValue)")
                        let generatedImage = await previewRenderer.generatePreview(for: theme)
                        await MainActor.run {
                            self.previewImage = generatedImage
                        }
                    }
                } else {
                    print("🖼️ ThemePreviewCard: Background not ready, generating individual preview for \(theme.rawValue)")
                    let generatedImage = await previewRenderer.generatePreview(for: theme)
                    print("🖼️ ThemePreviewCard: Preview generated for \(theme.rawValue), size: \(generatedImage.size)")
                    await MainActor.run {
                        self.previewImage = generatedImage
                        print("🖼️ ThemePreviewCard: UI state updated for \(theme.rawValue)")
                    }
                }
            }
        }
    }
}

/// Table preview card showing expanded or collapsed state (matches Android exactly)
struct osrsTablePreviewCard: View {
    let title: String
    let subtitle: String
    let isSelected: Bool
    let collapsed: Bool
    let onSelect: () -> Void
    let tablePreviewRenderer: osrsTablePreviewRenderer
    
    @EnvironmentObject var themeManager: osrsThemeManager
    @Environment(\.osrsTheme) var osrsTheme
    @ObservedObject private var backgroundPreviewManager = osrsBackgroundPreviewManager.shared
    @State private var previewImage: UIImage? = nil
    
    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 0) {
                // Table preview image (actual rendered table like Android)
                Group {
                    if let previewImage = previewImage {
                        Image(uiImage: previewImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .onAppear {
                                print("📊 SHOWING GENERATED TABLE IMAGE for \(collapsed ? "collapsed" : "expanded") - size: \(previewImage.size)")
                            }
                    } else {
                        // Loading placeholder - show background generation progress
                        ZStack {
                            Color(osrsTheme.surface)
                            if backgroundPreviewManager.isGeneratingPreviews {
                                VStack(spacing: 8) {
                                    ProgressView(value: backgroundPreviewManager.generationProgress)
                                        .progressViewStyle(LinearProgressViewStyle())
                                        .frame(width: 80)
                                    Text("Generating...")
                                        .font(.caption2)
                                        .foregroundStyle(.osrsPlaceholderColor)
                                }
                            } else {
                                ProgressView()
                                    .scaleEffect(0.5)
                            }
                        }
                        .onAppear {
                            print("📊 LOADING TABLE PLACEHOLDER for \(collapsed ? "collapsed" : "expanded") - background ready: \(backgroundPreviewManager.arePreviewsReady)")
                        }
                    }
                }
                .frame(height: 100)
                .clipped()
                
                // Title and subtitle
                VStack(spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.osrsPrimaryTextColor)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.osrsSecondaryTextColor)
                        .multilineTextAlignment(.center)
                }
                .padding(12)
                .background(Color(osrsTheme.surface))
            }
        }
        .buttonStyle(PlainButtonStyle())
        .background(Color(osrsTheme.surface))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color(osrsTheme.primary) : Color(osrsTheme.outline), lineWidth: isSelected ? 2 : 1)
        )
        .onAppear {
            generateTablePreview()
        }
        .onChange(of: themeManager.selectedTheme) { _, _ in
            // Regenerate preview when theme changes
            print("📊 TablePreviewCard: Theme changed, regenerating \(collapsed ? "collapsed" : "expanded") preview")
            generateTablePreview()
        }
    }
    
    private func generateTablePreview() {
        print("📊 TablePreviewCard: Generating table preview for \(collapsed ? "collapsed" : "expanded") with theme \(themeManager.selectedTheme.rawValue) - background ready: \(backgroundPreviewManager.arePreviewsReady)")
        Task {
            if backgroundPreviewManager.arePreviewsReady {
                print("📊 TablePreviewCard: ⚡ INSTANT ACCESS - Using cached table preview for \(collapsed ? "collapsed" : "expanded")")
                // Get cached image directly - no generation needed!
                if let cachedImage = tablePreviewRenderer.getCachedTablePreview(collapsed: collapsed, theme: themeManager.currentTheme) {
                    await MainActor.run {
                        self.previewImage = cachedImage
                        print("📊 TablePreviewCard: ⚡ INSTANT LOAD - Cached table preview displayed for \(collapsed ? "collapsed" : "expanded")")
                    }
                } else {
                    print("⚠️ TablePreviewCard: Cache miss! Generating table preview for \(collapsed ? "collapsed" : "expanded")")
                    let generatedImage = await tablePreviewRenderer.generateTablePreview(
                        collapsed: collapsed, 
                        theme: themeManager.currentTheme
                    )
                    await MainActor.run {
                        self.previewImage = generatedImage
                    }
                }
            } else {
                print("📊 TablePreviewCard: Background not ready, generating individual table preview for \(collapsed ? "collapsed" : "expanded")")
                let generatedImage = await tablePreviewRenderer.generateTablePreview(
                    collapsed: collapsed, 
                    theme: themeManager.currentTheme
                )
                print("📊 TablePreviewCard: Table preview retrieved for \(collapsed ? "collapsed" : "expanded"), size: \(generatedImage.size)")
                await MainActor.run {
                    self.previewImage = generatedImage
                    print("📊 TablePreviewCard: UI state updated for \(collapsed ? "collapsed" : "expanded")")
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        AppearanceSettingsView()
            .environmentObject(osrsThemeManager.preview)
            .environment(\.osrsTheme, osrsLightTheme())
    }
}

#Preview("Dark Theme") {
    NavigationStack {
        AppearanceSettingsView()
            .environmentObject(osrsThemeManager.previewDark)
            .environment(\.osrsTheme, osrsDarkTheme())
    }
    .preferredColorScheme(.dark)
}

