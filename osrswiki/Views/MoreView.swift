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
                            title: "Appearance"
                        )
                    }
                    .listRowBackground(Color(osrsTheme.surfaceVariant))
                    
                    NavigationLink(destination: DonateView()) {
                        MoreRowView(
                            iconName: "heart.fill",
                            iconColor: Color(osrsTheme.primary),
                            title: "Donate"
                        )
                    }
                    .listRowBackground(Color(osrsTheme.surfaceVariant))
                    
                    NavigationLink(destination: AboutView()) {
                        MoreRowView(
                            iconName: "info.circle.fill",
                            iconColor: Color(osrsTheme.primary),
                            title: "About"
                        )
                    }
                    .listRowBackground(Color(osrsTheme.surfaceVariant))
                    
                    NavigationLink(destination: FeedbackView()) {
                        MoreRowView(
                            iconName: "envelope.fill",
                            iconColor: Color(osrsTheme.primary),
                            title: "Send Feedback"
                        )
                    }
                    .listRowBackground(Color(osrsTheme.surfaceVariant))
                }
                .listSectionSeparator(.hidden)
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .navigationTitle("More")
            .navigationBarTitleDisplayMode(.inline)
            .background(.osrsBackground)
            .toolbarBackground(.osrsSurface, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(themeManager.currentColorScheme, for: .navigationBar)
        }
    }
}

struct MoreRowView: View {
    let iconName: String
    let iconColor: Color
    let title: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: iconName)
                .foregroundColor(iconColor)
                .frame(width: 24, height: 24)
            
            Text(title)
                .font(.body)
                .foregroundStyle(.osrsPrimaryTextColor)
            
            Spacer()
        }
        .contentShape(Rectangle())
    }
}

#Preview {
    MoreView()
        .environmentObject(AppState())
        .environmentObject(osrsThemeManager.preview)
        .environment(\.osrsTheme, osrsLightTheme())
}