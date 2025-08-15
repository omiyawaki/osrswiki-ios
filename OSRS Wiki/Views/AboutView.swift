//
//  AboutView.swift
//  OSRS Wiki
//
//  Created on iOS feature parity session
//

import SwiftUI

struct AboutView: View {
    @EnvironmentObject var appState: AppState
    
    private let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    private let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                appHeaderSection
                versionSection
                creditsSection
                legalSection
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.large)
        .background(appState.currentTheme.backgroundColor)
    }
    
    private var appHeaderSection: some View {
        VStack(spacing: 16) {
            // App Icon
            Image("AppIcon") // TODO: Replace with actual app icon asset
                .resizable()
                .frame(width: 80, height: 80)
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            
            VStack(spacing: 4) {
                Text("OSRS Wiki")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("Your ultimate Old School RuneScape companion")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    private var versionSection: some View {
        VStack(spacing: 8) {
            Text("Version \(appVersion) (\(buildNumber))")
                .font(.body)
                .foregroundColor(.secondary)
            
            HStack(spacing: 16) {
                Button("What's New") {
                    // TODO: Show changelog/release notes
                }
                .foregroundColor(.blue)
                
                Button("Rate App") {
                    openAppStore()
                }
                .foregroundColor(.blue)
            }
            .font(.caption)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var creditsSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Credits")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            creditItem(
                title: "Jagex Ltd.",
                description: "Old School RuneScape is a trademark of Jagex Ltd. This app is not affiliated with or endorsed by Jagex.",
                buttonText: nil,
                buttonAction: nil
            )
            
            creditItem(
                title: "Old School RuneScape Wiki",
                description: "Content and information provided by the Old School RuneScape Wiki community. The wiki is a collaborative effort by players for players.",
                buttonText: "Visit Wiki",
                buttonAction: { openWiki() }
            )
            
            creditItem(
                title: "Wikimedia Foundation",
                description: "This app is inspired by the Wikipedia app and uses similar design patterns and user experience principles.",
                buttonText: nil,
                buttonAction: nil
            )
            
            creditItem(
                title: "Open Source Libraries",
                description: "This app is built with Swift and SwiftUI, using various open source libraries and frameworks.",
                buttonText: "View Licenses",
                buttonAction: { showLicenses() }
            )
        }
    }
    
    private var legalSection: some View {
        VStack(spacing: 12) {
            Divider()
            
            VStack(spacing: 8) {
                Button("Privacy Policy") {
                    openPrivacyPolicy()
                }
                .foregroundColor(.blue)
                
                Button("Terms of Service") {
                    openTermsOfService()
                }
                .foregroundColor(.blue)
                
                Button("Contact Developer") {
                    openContactDeveloper()
                }
                .foregroundColor(.blue)
            }
            .font(.body)
            
            Text("Made with ❤️ for the OSRS community")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 8)
        }
    }
    
    private func creditItem(title: String, description: String, buttonText: String?, buttonAction: (() -> Void)?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text(description)
                .font(.body)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            
            if let buttonText = buttonText, let buttonAction = buttonAction {
                Button(action: buttonAction) {
                    HStack {
                        Text(buttonText)
                        Image(systemName: "arrow.up.right")
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Actions
    private func openAppStore() {
        // TODO: Open App Store page for rating
        if let url = URL(string: "https://apps.apple.com/app/id1234567890") { // Replace with actual App Store URL
            UIApplication.shared.open(url)
        }
    }
    
    private func openWiki() {
        if let url = URL(string: "https://oldschool.runescape.wiki/") {
            UIApplication.shared.open(url)
        }
    }
    
    private func showLicenses() {
        // TODO: Show open source licenses view
    }
    
    private func openPrivacyPolicy() {
        // TODO: Open privacy policy URL
        if let url = URL(string: "https://oldschool.runescape.wiki/privacy") {
            UIApplication.shared.open(url)
        }
    }
    
    private func openTermsOfService() {
        // TODO: Open terms of service URL
        if let url = URL(string: "https://oldschool.runescape.wiki/terms") {
            UIApplication.shared.open(url)
        }
    }
    
    private func openContactDeveloper() {
        // TODO: Open email or contact form
        if let url = URL(string: "mailto:feedback@osrswiki.app?subject=OSRS%20Wiki%20iOS%20App%20Feedback") {
            UIApplication.shared.open(url)
        }
    }
}

#Preview {
    NavigationView {
        AboutView()
            .environmentObject(AppState())
    }
}