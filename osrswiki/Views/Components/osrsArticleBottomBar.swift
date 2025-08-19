//
//  osrsArticleBottomBar.swift
//  osrswiki
//
//  Created on iOS bottom bar implementation session
//  Replicates Android PageActionBar functionality and layout
//

import SwiftUI

struct osrsArticleBottomBar: View {
    @Environment(\.osrsTheme) var osrsTheme
    
    // Action callbacks - matching Android functionality
    let onSaveAction: () -> Void
    let onFindInPageAction: () -> Void
    let onAppearanceAction: () -> Void
    let onContentsAction: () -> Void
    
    // State properties - matching Android state management
    let isBookmarked: Bool
    let saveState: osrsArticleBottomBarSaveState
    let saveProgress: Double
    let hasTableOfContents: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Top separator line
            Rectangle()
                .frame(height: 0.33)
                .foregroundColor(Color(UIColor.separator))
            
            // Button content area
            HStack(spacing: 0) {
                // Save Button - replicates Android page_action_save
                osrsBottomBarButton(
                    iconName: saveButtonIconName,
                    text: saveButtonText,
                    action: onSaveAction,
                    isEnabled: saveState != .downloading,
                    tintColor: saveButtonTintColor
                )
                
                // Find in Article Button - replicates Android page_action_find_in_article
                osrsBottomBarButton(
                    iconName: "doc.text.magnifyingglass",
                    text: "Find",
                    action: onFindInPageAction
                )
                
                // Appearance Button - replicates Android page_action_theme
                osrsBottomBarButton(
                    iconName: "paintbrush",
                    text: "Appearance",
                    action: onAppearanceAction
                )
                
                // Contents Button - replicates Android page_action_contents
                osrsBottomBarButton(
                    iconName: "list.bullet",
                    text: "Contents",
                    action: onContentsAction,
                    isEnabled: hasTableOfContents
                )
            }
            .frame(height: 49) // Match actual iOS native tab bar height exactly
            .background(osrsTheme.surface)
        }
        .background(osrsTheme.surface)
    }
    
    // MARK: - Save Button State Management
    
    private var saveButtonIconName: String {
        switch saveState {
        case .notSaved:
            return "bookmark"
        case .downloading:
            return "arrow.down.circle"
        case .saved:
            return "bookmark.fill"
        case .error:
            return "exclamationmark.triangle"
        }
    }
    
    private var saveButtonText: String {
        switch saveState {
        case .notSaved:
            return "Save"
        case .downloading:
            return "Saving... \(Int(saveProgress * 100))%"
        case .saved:
            return "Saved"
        case .error:
            return "Retry"
        }
    }
    
    private var saveButtonTintColor: Color {
        switch saveState {
        case .notSaved:
            return osrsTheme.secondary
        case .downloading:
            return osrsTheme.secondary.opacity(0.6)
        case .saved:
            return .yellow
        case .error:
            return .red
        }
    }
}

// MARK: - Individual Bottom Bar Button Component

struct osrsBottomBarButton: View {
    @Environment(\.osrsTheme) var osrsTheme
    
    let iconName: String
    let text: String
    let action: () -> Void
    let isEnabled: Bool
    let tintColor: Color?
    
    init(iconName: String, text: String, action: @escaping () -> Void, isEnabled: Bool = true, tintColor: Color? = nil) {
        self.iconName = iconName
        self.text = text
        self.action = action
        self.isEnabled = isEnabled
        self.tintColor = tintColor
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 1) { // Tighter spacing for smaller height
                Image(systemName: iconName)
                    .font(.system(size: 20, weight: .medium)) // Slightly smaller icon for 49pt height
                    .foregroundColor(effectiveTintColor)
                    .frame(height: 28) // Adjusted for smaller container
                
                Text(text)
                    .font(.system(size: 10, weight: .medium)) // Keep native text size
                    .foregroundColor(effectiveTintColor)
                    .multilineTextAlignment(.center)
                    .lineLimit(1) // Single line like native tabs
                    .minimumScaleFactor(0.8)
                    .frame(height: 12) // Adjusted for smaller container
            }
            .frame(maxWidth: .infinity)
            .frame(height: 49) // Match exact native tab bar button height
            .contentShape(Rectangle()) // Ensure entire button area is tappable
        }
        .disabled(!isEnabled)
        .buttonStyle(PlainButtonStyle()) // Prevent default button styling
    }
    
    private var effectiveTintColor: Color {
        if let tintColor = tintColor {
            return isEnabled ? tintColor : tintColor.opacity(0.4)
        }
        return isEnabled ? osrsTheme.secondary : osrsTheme.secondary.opacity(0.4)
    }
}

// MARK: - Preview

#Preview("Light Theme") {
    VStack {
        Spacer()
        osrsArticleBottomBar(
            onSaveAction: { print("Save tapped") },
            onFindInPageAction: { print("Find tapped") },
            onAppearanceAction: { print("Appearance tapped") },
            onContentsAction: { print("Contents tapped") },
            isBookmarked: false,
            saveState: .notSaved,
            saveProgress: 0.0,
            hasTableOfContents: true
        )
    }
    .environment(\.osrsTheme, osrsLightTheme())
}

#Preview("Dark Theme - Saving") {
    VStack {
        Spacer()
        osrsArticleBottomBar(
            onSaveAction: { print("Save tapped") },
            onFindInPageAction: { print("Find tapped") },
            onAppearanceAction: { print("Appearance tapped") },
            onContentsAction: { print("Contents tapped") },
            isBookmarked: false,
            saveState: .downloading,
            saveProgress: 0.65,
            hasTableOfContents: false
        )
    }
    .environment(\.osrsTheme, osrsDarkTheme())
}

#Preview("Saved State") {
    VStack {
        Spacer()
        osrsArticleBottomBar(
            onSaveAction: { print("Save tapped") },
            onFindInPageAction: { print("Find tapped") },
            onAppearanceAction: { print("Appearance tapped") },
            onContentsAction: { print("Contents tapped") },
            isBookmarked: true,
            saveState: .saved,
            saveProgress: 1.0,
            hasTableOfContents: true
        )
    }
    .environment(\.osrsTheme, osrsLightTheme())
}