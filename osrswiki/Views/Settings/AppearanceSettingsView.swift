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
        NavigationStack {
            List {
                Section {
                    // Theme selection row
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Theme")
                            .font(.body)
                            .foregroundStyle(.osrsPrimaryTextColor)
                        
                        // Three cards horizontally arranged, right-aligned
                        HStack(spacing: 8) {
                            Spacer()
                            
                            osrsThemePreviewCard(
                                theme: .osrsLight,
                                isSelected: themeManager.selectedTheme == .osrsLight,
                                onSelect: { themeManager.setTheme(.osrsLight) },
                                previewRenderer: themePreviewRenderer
                            )
                            
                            osrsThemePreviewCard(
                                theme: .osrsDark,
                                isSelected: themeManager.selectedTheme == .osrsDark,
                                onSelect: { themeManager.setTheme(.osrsDark) },
                                previewRenderer: themePreviewRenderer
                            )
                            
                            osrsThemePreviewCard(
                                theme: .automatic,
                                isSelected: themeManager.selectedTheme == .automatic,
                                onSelect: { themeManager.setTheme(.automatic) },
                                previewRenderer: themePreviewRenderer
                            )
                        }
                    }
                    .padding(.vertical, 8)
                    .listRowBackground(Color(osrsTheme.surfaceVariant))
                    
                    // Table preferences row
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Tables")
                            .font(.body)
                            .foregroundStyle(.osrsPrimaryTextColor)
                        
                        HStack(spacing: 8) {
                            Spacer()
                            
                            // Expanded preview
                            osrsTablePreviewCard(
                                title: "Expanded",
                                subtitle: "",
                                isSelected: !themeManager.collapseTables,
                                collapsed: false,
                                onSelect: { themeManager.setCollapseTables(false) },
                                tablePreviewRenderer: tablePreviewRenderer
                            )
                            
                            // Collapsed preview
                            osrsTablePreviewCard(
                                title: "Collapsed", 
                                subtitle: "",
                                isSelected: themeManager.collapseTables,
                                collapsed: true,
                                onSelect: { themeManager.setCollapseTables(true) },
                                tablePreviewRenderer: tablePreviewRenderer
                            )
                        }
                    }
                    .padding(.vertical, 8)
                    .listRowBackground(Color(osrsTheme.surfaceVariant))
                }
                .listSectionSeparator(.hidden)
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Appearance")
        .navigationBarTitleDisplayMode(.inline)
        .background(.osrsBackground)
        .scrollContentBackground(.hidden)
        // Force navigation bar to update with current theme
        .toolbarBackground(.osrsSurface, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(themeManager.currentColorScheme, for: .navigationBar)
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
            VStack(spacing: 4) {
                // Maximized preview image area - uses most of button space
                ZStack(alignment: .center) {
                    Color(osrsTheme.surfaceVariant)
                    
                    if let previewImage = previewImage {
                        Image(uiImage: previewImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 82, height: 120)
                            .clipped()
                            .onAppear {
                                print("🖼️ SHOWING GENERATED IMAGE for \(theme.rawValue) - size: \(previewImage.size)")
                            }
                    } else {
                        // Loading placeholder
                        if backgroundPreviewManager.isGeneratingPreviews {
                            VStack(spacing: 4) {
                                ProgressView(value: backgroundPreviewManager.generationProgress)
                                    .progressViewStyle(LinearProgressViewStyle())
                                    .tint(.osrsPrimaryColor)
                                    .frame(width: 50)
                                Text("Loading...")
                                    .font(.caption2)
                                    .foregroundStyle(.osrsPlaceholderColor)
                            }
                        } else {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .tint(.osrsPrimaryColor)
                                .scaleEffect(0.7)
                        }
                    }
                }
                .frame(width: 82, height: 120)
                .background(Color(osrsTheme.surfaceVariant))
                .cornerRadius(6)
                
                // Compact title - minimal space
                Text(theme.displayName)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.osrsPrimaryTextColor)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .frame(height: 14)
            }
            .frame(width: 90)
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
        .background(Color(osrsTheme.surfaceVariant))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color(osrsTheme.primary) : Color.clear, lineWidth: 2)
        )
        .overlay(alignment: .topTrailing) {
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.white, Color(osrsTheme.primary))
                    .font(.system(size: 16))
                    .offset(x: -6, y: 6)
            }
        }
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
            VStack(spacing: 4) {
                // Maximized table preview image - uses most of button space
                ZStack(alignment: .center) {
                    Color(osrsTheme.surfaceVariant)
                    
                    if let previewImage = previewImage {
                        Image(uiImage: previewImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 82, height: 120)
                            .clipped()
                            .onAppear {
                                print("📊 SHOWING GENERATED TABLE IMAGE for \(collapsed ? "collapsed" : "expanded") - size: \(previewImage.size)")
                            }
                    } else {
                        // Loading placeholder
                        if backgroundPreviewManager.isGeneratingPreviews {
                            VStack(spacing: 4) {
                                ProgressView(value: backgroundPreviewManager.generationProgress)
                                    .progressViewStyle(LinearProgressViewStyle())
                                    .tint(.osrsPrimaryColor)
                                    .frame(width: 50)
                                Text("Loading...")
                                    .font(.caption2)
                                    .foregroundStyle(.osrsPlaceholderColor)
                            }
                        } else {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .tint(.osrsPrimaryColor)
                                .scaleEffect(0.7)
                        }
                    }
                }
                .frame(width: 82, height: 120)
                .background(Color(osrsTheme.surfaceVariant))
                .cornerRadius(6)
                
                // Compact title - minimal space
                Text(title)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.osrsPrimaryTextColor)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .frame(height: 14)
            }
            .frame(width: 90)
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
        .background(Color(osrsTheme.surfaceVariant))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color(osrsTheme.primary) : Color.clear, lineWidth: 2)
        )
        .overlay(alignment: .topTrailing) {
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.white, Color(osrsTheme.primary))
                    .font(.system(size: 16))
                    .offset(x: -6, y: 6)
            }
        }
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

