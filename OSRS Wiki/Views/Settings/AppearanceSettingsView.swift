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

