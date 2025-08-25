//
//  CustomTabBar.swift
//  OSRS Wiki
//
//  Created to bypass iOS 18 SwiftUI TabView color limitations
//  Provides complete control over tab bar colors and appearance
//

import SwiftUI

// MARK: - Custom Tab Bar View

struct CustomTabBar: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: osrsThemeManager
    
    let items: [TabItem] = [.news, .saved, .search, .map, .more]
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(items, id: \.self) { item in
                CustomTabItem(
                    item: item,
                    isSelected: appState.selectedTab == item
                ) {
                    // Handle tab selection
                    withAnimation(.easeInOut(duration: 0.2)) {
                        appState.setSelectedTab(item)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 50) // Standard tab bar height
        .background(Color(themeManager.currentTheme.surface))
        .overlay(
            // Top border to separate from content
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Color(themeManager.currentTheme.outline).opacity(0.3)),
            alignment: .top
        )
    }
}

// MARK: - Custom Tab Item

struct CustomTabItem: View {
    @EnvironmentObject var themeManager: osrsThemeManager
    
    let item: TabItem
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: isSelected ? item.selectedIconName : item.iconName)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(tabItemColor)
                
                Text(item.title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(tabItemColor)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .contentShape(Rectangle()) // Expand tap area
        }
        .buttonStyle(PlainButtonStyle()) // Remove default button styling
    }
    
    /// Calculate exact tab item color based on selection state
    private var tabItemColor: Color {
        if isSelected {
            // Active: Use primary text color
            return Color(themeManager.currentTheme.primaryTextColor)
        } else {
            // Inactive: Use our EXACT calculated color to match Android
            return Color(themeManager.currentTheme.bottomNavInactiveColor) // #9e9583
        }
    }
}

// MARK: - Preview

#Preview {
    VStack {
        Spacer()
        CustomTabBar()
            .environmentObject(AppState())
            .environmentObject(osrsThemeManager.preview)
    }
}