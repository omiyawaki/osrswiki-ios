//
//  MoreView.swift
//  OSRS Wiki
//
//  Created on iOS development session
//

import SwiftUI

struct MoreView: View {
    @EnvironmentObject var appState: AppState
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
            .background(appState.currentTheme.backgroundColor)
        }
    }
    
    private var settingsSection: some View {
        Section("Settings") {
            NavigationLink(destination: AppearanceSettingsView()) {
                MoreRowView(
                    iconName: "paintbrush.fill",
                    iconColor: .blue,
                    title: "Appearance",
                    subtitle: "Themes and display settings"
                )
            }
            
            NavigationLink(destination: OfflineSettingsView()) {
                MoreRowView(
                    iconName: "arrow.down.circle.fill",
                    iconColor: .green,
                    title: "Offline Content",
                    subtitle: "Download pages for offline reading"
                )
            }
            
            NavigationLink(destination: NotificationSettingsView()) {
                MoreRowView(
                    iconName: "bell.fill",
                    iconColor: .orange,
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
                    iconColor: .purple,
                    title: "Reading History",
                    subtitle: "Pages you've visited"
                )
            }
            
            Button(action: {
                viewModel.clearCache()
            }) {
                MoreRowView(
                    iconName: "trash.fill",
                    iconColor: .red,
                    title: "Clear Cache",
                    subtitle: "Free up storage space"
                )
            }
            .foregroundColor(.primary)
            
            NavigationLink(destination: StorageView()) {
                MoreRowView(
                    iconName: "externaldrive.fill",
                    iconColor: .gray,
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
                    iconColor: .pink,
                    title: "Donate",
                    subtitle: "Support OSRS Wiki development"
                )
            }
            
            NavigationLink(destination: FeedbackView()) {
                MoreRowView(
                    iconName: "envelope.fill",
                    iconColor: .blue,
                    title: "Send Feedback",
                    subtitle: "Report issues or request features"
                )
            }
            
            Button(action: {
                viewModel.shareApp()
            }) {
                MoreRowView(
                    iconName: "square.and.arrow.up.fill",
                    iconColor: .green,
                    title: "Share App",
                    subtitle: "Tell others about OSRS Wiki"
                )
            }
            .foregroundColor(.primary)
            
            Button(action: {
                viewModel.rateApp()
            }) {
                MoreRowView(
                    iconName: "star.fill",
                    iconColor: .yellow,
                    title: "Rate App",
                    subtitle: "Rate us on the App Store"
                )
            }
            .foregroundColor(.primary)
        }
    }
    
    private var aboutSection: some View {
        Section("About") {
            NavigationLink(destination: AboutView()) {
                MoreRowView(
                    iconName: "info.circle.fill",
                    iconColor: .blue,
                    title: "About",
                    subtitle: "App version and information"
                )
            }
            
            Button(action: {
                viewModel.openPrivacyPolicy()
            }) {
                MoreRowView(
                    iconName: "hand.raised.fill",
                    iconColor: .orange,
                    title: "Privacy Policy",
                    subtitle: "How we handle your data"
                )
            }
            .foregroundColor(.primary)
            
            Button(action: {
                viewModel.openTermsOfService()
            }) {
                MoreRowView(
                    iconName: "doc.text.fill",
                    iconColor: .gray,
                    title: "Terms of Service",
                    subtitle: "Usage terms and conditions"
                )
            }
            .foregroundColor(.primary)
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
                    .font(.body)
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    MoreView()
        .environmentObject(AppState())
}