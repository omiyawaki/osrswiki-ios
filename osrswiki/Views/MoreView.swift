//
//  MoreView.swift
//  OSRS Wiki
//
//  Created on iOS development session
//

import SwiftUI

struct MoreView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: osrsThemeManager
    @Environment(\.osrsTheme) var osrsTheme
    @StateObject private var viewModel = MoreViewModel()
    
    var body: some View {
        NavigationStack(path: $appState.navigationPath) {
            List {
                // App settings section
                settingsSection
                
                // Content sections
                contentSection
                
                // Support section
                supportSection
                
                // About section
                aboutSection
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("More")
            .navigationBarTitleDisplayMode(.large)
            .background(.osrsBackground)
            .scrollContentBackground(.hidden)
        }
    }
    
    private var settingsSection: some View {
        Section("Settings") {
            NavigationLink(destination: AppearanceSettingsView()) {
                MoreRowView(
                    iconName: "paintbrush.fill",
                    iconColor: .osrsPrimaryColor,
                    title: "Appearance",
                    subtitle: "Themes and display settings"
                )
            }
            
            NavigationLink(destination: OfflineSettingsView()) {
                MoreRowView(
                    iconName: "arrow.down.circle.fill",
                    iconColor: .osrsAccentColor,
                    title: "Offline Content",
                    subtitle: "Download pages for offline reading"
                )
            }
            
            NavigationLink(destination: NotificationSettingsView()) {
                MoreRowView(
                    iconName: "bell.fill",
                    iconColor: .osrsSecondaryColor,
                    title: "Notifications",
                    subtitle: "News and update preferences"
                )
            }
        }
    }
    
    private var contentSection: some View {
        Section("Content") {
            NavigationLink(destination: HistoryView()) {
                MoreRowView(
                    iconName: "clock.fill",
                    iconColor: .osrsSecondaryColor,
                    title: "Reading History",
                    subtitle: "Pages you've visited"
                )
            }
            
            Button(action: {
                viewModel.clearCache()
            }) {
                MoreRowView(
                    iconName: "trash.fill",
                    iconColor: .osrsErrorColor,
                    title: "Clear Cache",
                    subtitle: "Free up storage space"
                )
            }
            .foregroundStyle(.osrsOnSurface)
            
            NavigationLink(destination: StorageView()) {
                MoreRowView(
                    iconName: "externaldrive.fill",
                    iconColor: .osrsOnSurfaceVariantColor,
                    title: "Storage",
                    subtitle: "Manage downloaded content"
                )
            }
        }
    }
    
    private var supportSection: some View {
        Section("Support") {
            NavigationLink(destination: DonateView()) {
                MoreRowView(
                    iconName: "heart.fill",
                    iconColor: .osrsErrorColor,
                    title: "Donate",
                    subtitle: "Support OSRS Wiki development"
                )
            }
            
            NavigationLink(destination: FeedbackView()) {
                MoreRowView(
                    iconName: "envelope.fill",
                    iconColor: .osrsPrimaryColor,
                    title: "Send Feedback",
                    subtitle: "Report issues or request features"
                )
            }
            
            Button(action: {
                viewModel.shareApp()
            }) {
                MoreRowView(
                    iconName: "square.and.arrow.up.fill",
                    iconColor: .osrsAccentColor,
                    title: "Share App",
                    subtitle: "Tell others about OSRS Wiki"
                )
            }
            .foregroundStyle(.osrsOnSurface)
            
            Button(action: {
                viewModel.rateApp()
            }) {
                MoreRowView(
                    iconName: "star.fill",
                    iconColor: .osrsSecondaryColor,
                    title: "Rate App",
                    subtitle: "Rate us on the App Store"
                )
            }
            .foregroundStyle(.osrsOnSurface)
        }
    }
    
    private var aboutSection: some View {
        Section("About") {
            NavigationLink(destination: AboutView()) {
                MoreRowView(
                    iconName: "info.circle.fill",
                    iconColor: .osrsPrimaryColor,
                    title: "About",
                    subtitle: "App version and information"
                )
            }
            
            Button(action: {
                viewModel.openPrivacyPolicy()
            }) {
                MoreRowView(
                    iconName: "hand.raised.fill",
                    iconColor: .osrsSecondaryColor,
                    title: "Privacy Policy",
                    subtitle: "How we handle your data"
                )
            }
            .foregroundStyle(.osrsOnSurface)
            
            Button(action: {
                viewModel.openTermsOfService()
            }) {
                MoreRowView(
                    iconName: "doc.text.fill",
                    iconColor: .osrsOnSurfaceVariantColor,
                    title: "Terms of Service",
                    subtitle: "Usage terms and conditions"
                )
            }
            .foregroundStyle(.osrsOnSurface)
        }
    }
}

struct MoreRowView: View {
    let iconName: String
    let iconColor: Color
    let title: String
    let subtitle: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .foregroundColor(iconColor)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.osrsTitle)
                    .foregroundStyle(.osrsOnSurface)
                    .onAppear {
                        if title == "Appearance" { // Only log once
                            print("🔍 MORE VIEW FONT TEST:")
                            print("   .osrsTitle should use: Alegreya-Medium")
                            let testFont = UIFont(name: "Alegreya-Medium", size: 20)
                            print("   Alegreya-Medium available: \(testFont != nil)")
                            if let font = testFont {
                                print("   Font family: '\(font.familyName)' name: '\(font.fontName)'")
                            }
                        }
                    }
                
                Text(subtitle)
                    .font(.osrsBody)
                    .foregroundStyle(.osrsOnSurfaceVariant)
            }
            
            Spacer()
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    MoreView()
        .environmentObject(AppState())
        .environmentObject(osrsThemeManager.preview)
        .environment(\.osrsTheme, osrsLightTheme())
}