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
        NavigationStack(path: $appState.moreNavigationPath) {
            List {
                Section {
                    NavigationLink(destination: AppearanceSettingsView()) {
                        MoreRowView(
                            iconName: "paintbrush.fill",
                            iconColor: Color(osrsTheme.primary),
                            title: "Appearance",
                            subtitle: "Themes and display settings"
                        )
                    }
                    .listRowBackground(osrsTheme.surface)
                    
                    NavigationLink(destination: DonateView()) {
                        MoreRowView(
                            iconName: "heart.fill",
                            iconColor: Color(osrsTheme.error),
                            title: "Donate",
                            subtitle: "Support OSRS Wiki development"
                        )
                    }
                    .listRowBackground(osrsTheme.surface)
                    
                    NavigationLink(destination: AboutView()) {
                        MoreRowView(
                            iconName: "info.circle.fill",
                            iconColor: Color(osrsTheme.primary),
                            title: "About",
                            subtitle: "App version and information"
                        )
                    }
                    .listRowBackground(osrsTheme.surface)
                    
                    NavigationLink(destination: FeedbackView()) {
                        MoreRowView(
                            iconName: "envelope.fill",
                            iconColor: Color(osrsTheme.primary),
                            title: "Send Feedback",
                            subtitle: "Report issues or request features"
                        )
                    }
                    .listRowBackground(osrsTheme.surface)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("More")
            .navigationBarTitleDisplayMode(.large)
            .background(.osrsBackground)
            .scrollContentBackground(.hidden)
            .environment(\.defaultMinListRowHeight, 60)
            .toolbarBackground(osrsTheme.surface, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(themeManager.currentColorScheme == .dark ? .dark : .light, for: .navigationBar)
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
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(.osrsOnSurface)
                
                Text(subtitle)
                    .font(.osrsBody)
                    .foregroundStyle(.osrsSecondaryTextColor)
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