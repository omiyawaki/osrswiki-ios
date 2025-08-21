//
//  AboutView.swift
//  OSRS Wiki
//
//  Updated to match Android About page exactly
//

import SwiftUI

struct AboutView: View {
    @Environment(\.osrsTheme) var osrsTheme
    @EnvironmentObject var themeManager: osrsThemeManager
    
    private let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    private let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                titleSection
                versionSection
                creditsSection
                privacySection
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 24)
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
        .background(.osrsBackground)
        .toolbarBackground(osrsTheme.surface, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(themeManager.currentColorScheme == .dark ? .dark : .light, for: .navigationBar)
    }
    
    private var titleSection: some View {
        Text("About OSRS Wiki App")
            .font(.osrsDisplay)
            .foregroundStyle(.osrsOnSurface)
            .multilineTextAlignment(.center)
    }
    
    private var versionSection: some View {
        Text("Version \(appVersion) (\(buildNumber))")
            .font(.osrsBody)
            .foregroundStyle(.osrsSecondaryTextColor)
            .multilineTextAlignment(.center)
    }
    
    private var creditsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Credits & Acknowledgments")
                .font(.osrsHeadline)
                .foregroundStyle(.osrsOnSurface)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            creditItem(
                title: "Old School RuneScape",
                description: "Jagex®, RuneScape®, and Old School RuneScape® are registered and/or unregistered trademarks of Jagex in the United Kingdom, the United States, the European Union and other territories."
            )
            
            VStack(alignment: .leading, spacing: 8) {
                creditItem(
                    title: "OSRS Wiki",
                    description: "All information and game content fetched by this app is provided by the Old School Runescape Wiki. This app would not be possible without the wiki itself."
                )
                
                Button(action: openWiki) {
                    HStack {
                        Text("Visit OSRS Wiki")
                        Image(systemName: "arrow.up.right")
                    }
                    .font(.osrsBody)
                    .foregroundStyle(.osrsPrimary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
            }
            
            creditItem(
                title: "Wikipedia",
                description: "This app's design and architecture were influenced by the Wikipedia app. In the spirit of both Oldschool Runescape Wiki and Wikipedia's free and open source principles, the OSRS Wiki app is and will always be free."
            )
        }
    }
    
    private var privacySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Privacy Policy")
                .font(.osrsHeadline)
                .foregroundStyle(.osrsOnSurface)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text("The OSRS Wiki App collects minimal user data, primarily voice search recordings processed locally and temporarily, and usage metrics to improve app functionality. The app does not permanently store personal information.")
                .font(.osrsBody)
                .foregroundStyle(.osrsSecondaryTextColor)
                .fixedSize(horizontal: false, vertical: true)
            
            Button(action: openPrivacyPolicy) {
                HStack {
                    Text("View Privacy Policy")
                    Image(systemName: "arrow.up.right")
                }
                .font(.osrsBody)
                .foregroundStyle(.osrsPrimary)
            }
            .frame(maxWidth: .infinity)
        }
    }
    
    private func creditItem(title: String, description: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.osrsTitle)
                .foregroundStyle(.osrsOnSurface)
            
            Text(description)
                .font(.osrsBody)
                .foregroundStyle(.osrsSecondaryTextColor)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Actions
    private func openWiki() {
        if let url = URL(string: "https://oldschool.runescape.wiki/") {
            UIApplication.shared.open(url)
        }
    }
    
    private func openPrivacyPolicy() {
        if let url = URL(string: "https://osrswiki.github.io/osrswiki-privacy-policy/") {
            UIApplication.shared.open(url)
        }
    }
}

#Preview {
    NavigationView {
        AboutView()
            .environmentObject(osrsThemeManager.preview)
            .environment(\.osrsTheme, osrsLightTheme())
    }
}