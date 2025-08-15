//
//  AppearanceSettingsView.swift
//  OSRS Wiki
//
//  Created on iOS development session
//

import SwiftUI

struct AppearanceSettingsView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        List {
            Section("Theme") {
                ForEach(AppTheme.allCases, id: \.self) { theme in
                    Button(action: {
                        appState.setTheme(theme)
                    }) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(theme.displayName)
                                    .foregroundColor(.primary)
                                
                                if theme.isOSRSTheme {
                                    Text("OSRS-themed colors and styling")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            if appState.currentTheme == theme {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                }
            }
            
            Section("Preview") {
                VStack(spacing: 16) {
                    Text("Theme Preview")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    HStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(appState.currentTheme.primaryColor)
                            .frame(width: 60, height: 40)
                        
                        RoundedRectangle(cornerRadius: 8)
                            .fill(appState.currentTheme.backgroundColor)
                            .frame(width: 60, height: 40)
                        
                        RoundedRectangle(cornerRadius: 8)
                            .fill(appState.currentTheme.secondaryBackgroundColor)
                            .frame(width: 60, height: 40)
                    }
                }
                .padding()
                .background(appState.currentTheme.backgroundColor)
                .cornerRadius(12)
            }
        }
        .navigationTitle("Appearance")
        .navigationBarTitleDisplayMode(.inline)
        .background(appState.currentTheme.backgroundColor)
    }
}

struct OfflineSettingsView: View {
    var body: some View {
        List {
            Section("Download Settings") {
                Text("Configure offline content downloading")
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Offline Content")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct NotificationSettingsView: View {
    var body: some View {
        List {
            Section("Notifications") {
                Text("Configure notification preferences")
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct HistoryView: View {
    var body: some View {
        List {
            Section("Reading History") {
                Text("View your reading history")
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct StorageView: View {
    var body: some View {
        List {
            Section("Storage Usage") {
                Text("Manage downloaded content and cache")
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Storage")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct DonateView: View {
    var body: some View {
        List {
            Section("Support OSRS Wiki") {
                Text("Help support the development of OSRS Wiki")
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Donate")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct FeedbackView: View {
    var body: some View {
        List {
            Section("Send Feedback") {
                Text("Report issues or request features")
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Feedback")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct AboutView: View {
    var body: some View {
        List {
            Section("App Information") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Build")
                    Spacer()
                    Text("1")
                        .foregroundColor(.secondary)
                }
            }
            
            Section("Credits") {
                Text("This app is built for the OSRS Wiki community")
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }
}