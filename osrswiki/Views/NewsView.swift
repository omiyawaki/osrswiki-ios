//
//  NewsView.swift
//  OSRS Wiki
//
//  Created on iOS development session
//

import SwiftUI

struct NewsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: osrsThemeManager
    @Environment(\.osrsTheme) var osrsTheme
    @StateObject private var viewModel = NewsViewModel()
    
    var body: some View {
        NavigationStack(path: $appState.newsNavigationPath) {
            VStack(spacing: 0) {
                // Custom header matching Android
                HeaderView()
                
                ScrollView {
                    LazyVStack(spacing: 12) {
                        // Search bar at top (matches Android)
                        SearchBarView(placeholder: "Search OSRS Wiki") {
                            // Navigate to search using NavigationStack
                            appState.navigateToSearch()
                        }
                        .padding(.horizontal)
                        
                        // Feed content matching Android structure
                        if viewModel.isLoading {
                            ProgressView("Loading news...")
                                .frame(maxWidth: .infinity, minHeight: 200)
                        } else if let wikiFeed = viewModel.wikiFeed {
                            // Recent Updates section (horizontal scrolling)
                            if !wikiFeed.recentUpdates.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Recent updates")
                                        .font(.osrsSectionHeaderSmallCaps)
                                        .foregroundStyle(.osrsOnSurface)
                                        .kerning(0.5)
                                        .padding(.horizontal, 16)
                                    
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        LazyHStack(spacing: 12) {
                                            ForEach(wikiFeed.recentUpdates) { update in
                                                UpdateCardView(updateItem: update) {
                                                    // Navigate to article
                                                    if !update.articleUrl.isEmpty {
                                                        appState.navigateToArticle(url: URL(string: update.articleUrl)!)
                                                    }
                                                }
                                                .zIndex(1) // Ensure cards are above other content
                                            }
                                        }
                                        .padding(.horizontal, 16)
                                        // Removed vertical padding to match other sections' spacing
                                    }
                                }
                                .padding(.vertical, 8)
                            }
                            
                            // Announcements section (show only first like Android)
                            if let firstAnnouncement = wikiFeed.announcements.first {
                                AnnouncementCardView(announcementItem: firstAnnouncement) { url in
                                    if let articleUrl = URL(string: url) {
                                        appState.navigateToArticle(url: articleUrl)
                                    }
                                }
                            }
                            
                            // On This Day section
                            if let onThisDay = wikiFeed.onThisDay {
                                OnThisDayCardView(onThisDayItem: onThisDay) { url in
                                    if let articleUrl = URL(string: url) {
                                        appState.navigateToArticle(url: articleUrl)
                                    }
                                }
                            }
                            
                            // Popular Pages section
                            if !wikiFeed.popularPages.isEmpty {
                                PopularPagesCardView(popularPages: wikiFeed.popularPages) { url in
                                    if let articleUrl = URL(string: url) {
                                        appState.navigateToArticle(url: articleUrl)
                                    }
                                }
                            }
                        } else {
                            EmptyStateView(
                                iconName: "newspaper",
                                title: "No News Available",
                                subtitle: "Check back later for OSRS updates"
                            )
                        }
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("")
            .navigationBarHidden(true)
            .refreshable {
                await viewModel.refresh()
            }
            .background(.osrsBackground)
            .navigationDestination(for: NavigationDestination.self) { destination in
                switch destination {
                case .search:
                    DedicatedSearchView()
                        .environmentObject(appState)
                        .environment(\.osrsTheme, osrsTheme)
                case .article(let articleDestination):
                    ArticleView(pageTitle: articleDestination.title, pageUrl: articleDestination.url)
                        .environmentObject(appState)
                        .environment(\.osrsTheme, osrsTheme)
                }
            }
        }
        .task {
            await viewModel.loadNews()
        }
    }
}

struct SearchBarView: View {
    let placeholder: String
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.osrsPlaceholderColor)
                    .font(.system(size: 16, weight: .medium))
                
                Text(placeholder)
                    .foregroundStyle(.osrsSecondaryTextColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // Voice search icon on the far right (matches Android)
                Image(systemName: "mic")
                    .foregroundStyle(.osrsSecondaryTextColor)
                    .font(.system(size: 16, weight: .medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .frame(height: 36)
            .background(.osrsSearchBoxBackgroundColor)
            .cornerRadius(18)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct EmptyStateView: View {
    let iconName: String
    let title: String
    let subtitle: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: iconName)
                .font(.system(size: 48))
                .foregroundStyle(.osrsPlaceholderColor)
            
            VStack(spacing: 8) {
                Text(title)
                    .font(.osrsHeadline)
                    .foregroundStyle(.osrsPrimaryTextColor)
                
                Text(subtitle)
                    .font(.osrsBody)
                    .foregroundStyle(.osrsSecondaryTextColor)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 200)
    }
}

struct HeaderView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        HStack {
            // Left-aligned "Home" title matching Android
            Text("Home")
                .font(.osrsDisplay)
                .foregroundStyle(.osrsPrimaryTextColor)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Random page button (matching Android)
            Button(action: {
                // TODO: Implement random page navigation
                print("Random page button tapped")
            }) {
                Image(systemName: "shuffle")
                    .font(.system(size: 24))
                    .foregroundStyle(.osrsSecondaryTextColor)
                    .frame(width: 48, height: 48)
            }
            .accessibilityLabel("Random page")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.osrsBackground)
    }
}

// MARK: - Content Section Views

struct UpdateCardView: View {
    let updateItem: UpdateItem
    let onTap: () -> Void
    @Environment(\.osrsPreviewMode) private var isPreviewMode
    @ObservedObject private var imageCache = osrsImageCache.shared
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                // Image section - use cached images in preview mode, AsyncImage otherwise
                Group {
                    if isPreviewMode, let cachedImage = imageCache.getCachedImage(for: updateItem.imageUrl) {
                        // Preview mode: use pre-loaded cached image for reliable rendering
                        Image(uiImage: cachedImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        // Normal mode or preview fallback: use AsyncImage
                        AsyncImage(url: URL(string: updateItem.imageUrl)) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            case .failure(_):
                                // Fallback with OSRS-style colors (browns/tans) instead of blue
                                RoundedRectangle(cornerRadius: 0)
                                    .fill(LinearGradient(
                                        colors: [Color(red: 0.7, green: 0.6, blue: 0.4), Color(red: 0.5, green: 0.4, blue: 0.3)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ))
                                    .overlay(
                                        VStack(spacing: 8) {
                                            Image(systemName: "photo.fill")
                                                .font(.system(size: 24, weight: .medium))
                                                .foregroundStyle(.white)
                                            Text("OSRS")
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundStyle(.white)
                                        }
                                    )
                            case .empty:
                                // Loading state with OSRS theme colors
                                Rectangle()
                                    .fill(.osrsSurfaceVariant)
                                    .overlay(
                                        ProgressView()
                                            .tint(Color.osrsAccentColor)
                                    )
                            @unknown default:
                                // Fallback
                                Rectangle()
                                    .fill(.osrsSurfaceVariant)
                            }
                        }
                    }
                }
                .frame(width: 280, height: 140)
                .clipped()
                
                // Content section
                VStack(alignment: .leading, spacing: 8) {
                    Text(updateItem.title)
                        .font(.osrsTitle)
                        .foregroundStyle(.osrsPrimaryTextColor)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    HTMLTextView(updateItem.snippet)
                        .font(.osrsBody)
                        .foregroundStyle(.osrsTextSecondary)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 12)
            }
        }
        .frame(width: 280)
        .background(.osrsSurfaceVariant)
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
        .shadow(color: .black.opacity(0.16), radius: 1, x: 0, y: 1)
        .buttonStyle(PlainButtonStyle())
    }
}

struct AnnouncementCardView: View {
    let announcementItem: AnnouncementItem
    let onLinkTap: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            Text("Announcements")
                .font(.osrsSectionHeaderSmallCaps)
                .foregroundStyle(.osrsOnSurface)
                .kerning(0.5)
                .padding(.horizontal, 16)
            
            // Card content
            VStack(alignment: .leading, spacing: 16) {
                HTMLTextView("\(announcementItem.date): \(announcementItem.content)") { url in
                    onLinkTap(url.absoluteString)
                }
                .font(.osrsBody)
                .foregroundStyle(.osrsOnSurface)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.osrsSurfaceVariant)
            .cornerRadius(8)
            .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
            .shadow(color: .black.opacity(0.16), radius: 1, x: 0, y: 1)
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 8)
    }
}

struct OnThisDayCardView: View {
    let onThisDayItem: OnThisDayItem
    let onLinkTap: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            Text(onThisDayItem.title)
                .font(.osrsSectionHeaderSmallCaps)
                .foregroundStyle(.osrsOnSurface)
                .kerning(0.5)
                .padding(.horizontal, 16)
            
            // Card content
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(onThisDayItem.events.enumerated()), id: \.offset) { index, event in
                    OnThisDayEventView(event: event) { url in
                        onLinkTap(url.absoluteString)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.osrsSurfaceVariant)
            .cornerRadius(8)
            .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
            .shadow(color: .black.opacity(0.16), radius: 1, x: 0, y: 1)
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 8)
    }
}

struct PopularPagesCardView: View {
    let popularPages: [PopularPageItem]
    let onLinkTap: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            Text("Popular pages")
                .font(.osrsSectionHeaderSmallCaps)
                .foregroundStyle(.osrsOnSurface)
                .kerning(0.5)
                .padding(.horizontal, 16)
            
            // Card content
            VStack(alignment: .leading, spacing: 8) {
                ForEach(popularPages) { page in
                    Button(action: { onLinkTap(page.pageUrl) }) {
                        Text(page.title)
                            .font(.osrsBody)
                            .foregroundStyle(.osrsLink)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.osrsSurfaceVariant)
            .cornerRadius(8)
            .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
            .shadow(color: .black.opacity(0.16), radius: 1, x: 0, y: 1)
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - On This Day Event View

/// Specialized view for "On This Day" events that applies monospace to years
struct OnThisDayEventView: View {
    let event: String
    let onLinkTap: (URL) -> Void
    
    var body: some View {
        MonospaceYearHTMLTextView("• \(event)") { url in
            onLinkTap(url)
        }
        .font(.osrsBody)
        .foregroundStyle(.osrsOnSurface)
        .lineLimit(1)
    }
}

/// Specialized HTMLTextView that applies monospace font to year patterns
struct MonospaceYearHTMLTextView: View {
    let htmlString: String
    let onLinkTap: ((URL) -> Void)?
    
    init(_ htmlString: String, onLinkTap: ((URL) -> Void)? = nil) {
        self.htmlString = htmlString
        self.onLinkTap = onLinkTap
    }
    
    var body: some View {
        if let attributedString = parseHTMLWithMonospaceYears(htmlString) {
            Text(AttributedString(attributedString))
                .environment(\.openURL, OpenURLAction { url in
                    if let onLinkTap = onLinkTap {
                        onLinkTap(url)
                        return .handled
                    }
                    return .systemAction
                })
        } else {
            Text(htmlString.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression))
        }
    }
    
    private func parseHTMLWithMonospaceYears(_ htmlString: String) -> NSAttributedString? {
        // For non-HTML text, create attributed string directly
        if !htmlString.contains("<") {
            let attributedString = NSMutableAttributedString(string: htmlString)
            let range = NSRange(location: 0, length: attributedString.length)
            
            // Apply base styling
            let systemFont = UIFont.systemFont(ofSize: 16)
            attributedString.addAttribute(.font, value: systemFont, range: range)
            attributedString.addAttribute(.foregroundColor, value: UIColor.label, range: range)
            
            // Apply monospace to year and dash pattern
            let text = attributedString.string
            do {
                let yearDashPattern = try NSRegularExpression(pattern: "^(• \\d{4} – )")
                let matches = yearDashPattern.matches(in: text, range: NSRange(location: 0, length: text.count))
                
                for match in matches {
                    let monoFont = UIFont.monospacedSystemFont(ofSize: 16, weight: .regular)
                    attributedString.addAttribute(.font, value: monoFont, range: match.range)
                }
            } catch {
                print("Error applying monospace pattern: \(error)")
            }
            
            return attributedString
        }
        
        // For HTML content, parse normally
        guard let data = htmlString.data(using: .utf8) else { return nil }
        
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]
        
        do {
            let attributedString = try NSMutableAttributedString(data: data, options: options, documentAttributes: nil)
            
            // Override HTML fonts and colors with theme-aware styling
            let range = NSRange(location: 0, length: attributedString.length)
            let systemFont = UIFont.systemFont(ofSize: 16)
            
            // Remove existing attributes and apply base styling
            attributedString.removeAttribute(.font, range: range)
            attributedString.removeAttribute(.foregroundColor, range: range)
            attributedString.addAttribute(.font, value: systemFont, range: range)
            attributedString.addAttribute(.foregroundColor, value: UIColor.label, range: range)
            
            // Fix link colors
            attributedString.enumerateAttribute(.link, in: range) { value, linkRange, _ in
                if value != nil {
                    // Use a theme-aware link color
                    let linkColor = UIColor { traitCollection in
                        if traitCollection.userInterfaceStyle == .dark {
                            return UIColor(red: 183/255, green: 157/255, blue: 126/255, alpha: 1.0) // osrs link color dark
                        } else {
                            return UIColor(red: 147/255, green: 96/255, blue: 57/255, alpha: 1.0) // osrs link color light
                        }
                    }
                    attributedString.addAttribute(.foregroundColor, value: linkColor, range: linkRange)
                }
            }
            
            // Apply monospace to year pattern
            let text = attributedString.string
            do {
                let yearDashPattern = try NSRegularExpression(pattern: "^(• \\d{4} – )")
                let matches = yearDashPattern.matches(in: text, range: NSRange(location: 0, length: text.count))
                
                for match in matches {
                    let monoFont = UIFont.monospacedSystemFont(ofSize: 16, weight: .regular)
                    attributedString.addAttribute(.font, value: monoFont, range: match.range)
                }
            } catch {
                print("Error applying monospace pattern: \(error)")
            }
            
            return attributedString
        } catch {
            print("Error parsing HTML: \(error)")
            return nil
        }
    }
}

// MARK: - HTML Content Helper

struct HTMLTextView: View {
    let htmlString: String
    let onLinkTap: ((URL) -> Void)?
    
    init(_ htmlString: String, onLinkTap: ((URL) -> Void)? = nil) {
        self.htmlString = htmlString
        self.onLinkTap = onLinkTap
    }
    
    var body: some View {
        if let attributedString = parseHTML(htmlString) {
            Text(AttributedString(attributedString))
                .environment(\.openURL, OpenURLAction { url in
                    if let onLinkTap = onLinkTap {
                        onLinkTap(url)
                        return .handled
                    }
                    return .systemAction
                })
        } else {
            Text(htmlString.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression))
        }
    }
    
    private func parseHTML(_ htmlString: String) -> NSAttributedString? {
        guard let data = htmlString.data(using: .utf8) else { return nil }
        
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]
        
        do {
            let attributedString = try NSMutableAttributedString(data: data, options: options, documentAttributes: nil)
            
            // Override HTML fonts and colors with theme-aware styling
            let range = NSRange(location: 0, length: attributedString.length)
            let systemFont = UIFont.systemFont(ofSize: 16) // Match .osrsBody size
            
            // Remove any existing font and color attributes
            attributedString.removeAttribute(.font, range: range)
            attributedString.removeAttribute(.foregroundColor, range: range)
            
            // Apply system font and theme text color
            attributedString.addAttribute(.font, value: systemFont, range: range)
            attributedString.addAttribute(.foregroundColor, value: UIColor.label, range: range) // Uses system dynamic color
            
            // Fix link colors to use theme colors
            attributedString.enumerateAttribute(.link, in: range) { value, linkRange, _ in
                if value != nil {
                    // Use theme-aware link color matching OSRS theme
                    let linkColor = UIColor { traitCollection in
                        if traitCollection.userInterfaceStyle == .dark {
                            return UIColor(red: 183/255, green: 157/255, blue: 126/255, alpha: 1.0) // osrs link color dark
                        } else {
                            return UIColor(red: 147/255, green: 96/255, blue: 57/255, alpha: 1.0) // osrs link color light
                        }
                    }
                    attributedString.addAttribute(.foregroundColor, value: linkColor, range: linkRange)
                }
            }
            
            return attributedString
        } catch {
            print("Error parsing HTML: \(error)")
            return nil
        }
    }
}

// MARK: - Preview-Optimized NewsView

/// Static NewsView that takes WikiFeed data directly (no ObservableObject) to avoid UIHostingController update issues
struct StaticNewsView: View {
    let wikiFeed: WikiFeed
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: osrsThemeManager
    @Environment(\.osrsTheme) var osrsTheme
    
    var body: some View {
        NavigationStack(path: $appState.newsNavigationPath) {
            VStack(spacing: 0) {
                // Custom header matching Android
                HeaderView()
                
                ScrollView {
                    LazyVStack(spacing: 16) {
                        // Search bar at top (matches Android)
                        SearchBarView(placeholder: "Search OSRS Wiki") {
                            // Navigate to search using NavigationStack
                            appState.navigateToSearch()
                        }
                        .padding(.horizontal)
                        
                        // Feed content matching Android structure - using STATIC data (no @Published dependencies)
                        let _ = print("🔍 StaticNewsView rendering with \(wikiFeed.recentUpdates.count) updates, \(wikiFeed.announcements.count) announcements")
                        
                        // Recent Updates section (horizontal scrolling)
                        if !wikiFeed.recentUpdates.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Recent updates")
                                    .font(.osrsSectionHeaderSmallCaps)
                                    .foregroundStyle(.osrsOnSurface)
                                    .textCase(.uppercase)
                                    .kerning(0.5)
                                    .padding(.horizontal, 16)
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    LazyHStack(spacing: 12) {
                                        ForEach(wikiFeed.recentUpdates) { update in
                                            UpdateCardView(updateItem: update) {
                                                // Navigate to article
                                                if !update.articleUrl.isEmpty {
                                                    appState.navigateToArticle(url: URL(string: update.articleUrl)!)
                                                }
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 16)
                                }
                            }
                            .padding(.vertical, 8)
                        }
                        
                        // Announcements section (show only first like Android)
                        if let firstAnnouncement = wikiFeed.announcements.first {
                            AnnouncementCardView(announcementItem: firstAnnouncement) { url in
                                if let articleUrl = URL(string: url) {
                                    appState.navigateToArticle(url: articleUrl)
                                }
                            }
                        }
                        
                        // On This Day section
                        if let onThisDay = wikiFeed.onThisDay {
                            OnThisDayCardView(onThisDayItem: onThisDay) { url in
                                if let articleUrl = URL(string: url) {
                                    appState.navigateToArticle(url: articleUrl)
                                }
                            }
                        }
                        
                        // Popular Pages section
                        if !wikiFeed.popularPages.isEmpty {
                            PopularPagesCardView(popularPages: wikiFeed.popularPages) { url in
                                if let articleUrl = URL(string: url) {
                                    appState.navigateToArticle(url: articleUrl)
                                }
                            }
                        }
                    }
                    .padding(.vertical)
                }
                .background(.osrsBackground)  // Apply theme background to ScrollView content
            }
        }
        .navigationTitle("")
        .navigationBarHidden(true)
        .background(.osrsBackground)
        .navigationDestination(for: NavigationDestination.self) { destination in
            switch destination {
            case .search:
                DedicatedSearchView()
                    .environmentObject(appState)
                    .environment(\.osrsTheme, osrsTheme)
            case .article(let articleDestination):
                ArticleView(pageTitle: articleDestination.title, pageUrl: articleDestination.url)
                    .environmentObject(appState)
                    .environment(\.osrsTheme, osrsTheme)
            }
        }
    }
}

/// NewsView variant that accepts a pre-loaded ViewModel to avoid timing issues in preview rendering
struct NewsViewWithPreloadedData: View {
    @ObservedObject var viewModel: NewsViewModel
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: osrsThemeManager
    @Environment(\.osrsTheme) var osrsTheme
    
    var body: some View {
        NavigationStack(path: $appState.newsNavigationPath) {
            VStack(spacing: 0) {
                // Custom header matching Android
                HeaderView()
                
                ScrollView {
                    LazyVStack(spacing: 16) {
                        // Search bar at top (matches Android)
                        SearchBarView(placeholder: "Search OSRS Wiki") {
                            // Navigate to search using NavigationStack
                            appState.navigateToSearch()
                        }
                        .padding(.horizontal)
                        
                        // Feed content matching Android structure - use pre-loaded data  
                        // DEBUG: Print state before rendering
                        let _ = print("🔍 NewsViewWithPreloadedData rendering: wikiFeed=\(viewModel.wikiFeed != nil ? "✅" : "❌"), updates=\(viewModel.wikiFeed?.recentUpdates.count ?? 0)")
                        if let wikiFeed = viewModel.wikiFeed {
                            // Recent Updates section (horizontal scrolling)
                            if !wikiFeed.recentUpdates.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Recent updates")
                                        .font(.osrsSectionHeaderSmallCaps)
                                        .foregroundStyle(.osrsOnSurface)
                                        .textCase(.uppercase)
                                        .kerning(0.5)
                                        .padding(.horizontal, 16)
                                    
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        LazyHStack(spacing: 12) {
                                            ForEach(wikiFeed.recentUpdates) { update in
                                                UpdateCardView(updateItem: update) {
                                                    // Navigate to article
                                                    if !update.articleUrl.isEmpty {
                                                        appState.navigateToArticle(url: URL(string: update.articleUrl)!)
                                                    }
                                                }
                                            }
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 16)
                                    }
                                }
                                .padding(.vertical, 8)
                            }
                            
                            // Announcements section (show only first like Android)
                            if let firstAnnouncement = wikiFeed.announcements.first {
                                AnnouncementCardView(announcementItem: firstAnnouncement) { url in
                                    if let articleUrl = URL(string: url) {
                                        appState.navigateToArticle(url: articleUrl)
                                    }
                                }
                            }
                            
                            // On This Day section
                            if let onThisDay = wikiFeed.onThisDay {
                                OnThisDayCardView(onThisDayItem: onThisDay) { url in
                                    if let articleUrl = URL(string: url) {
                                        appState.navigateToArticle(url: articleUrl)
                                    }
                                }
                            }
                            
                            // Popular Pages section
                            if !wikiFeed.popularPages.isEmpty {
                                PopularPagesCardView(popularPages: wikiFeed.popularPages) { url in
                                    if let articleUrl = URL(string: url) {
                                        appState.navigateToArticle(url: articleUrl)
                                    }
                                }
                            }
                        } else {
                            EmptyStateView(
                                iconName: "newspaper",
                                title: "No News Available",
                                subtitle: "Check back later for OSRS updates"
                            )
                        }
                    }
                    .padding(.vertical)
                }
            }
        }
        .navigationTitle("")
        .navigationBarHidden(true)
        .background(.osrsBackground)
        .navigationDestination(for: NavigationDestination.self) { destination in
            switch destination {
            case .search:
                DedicatedSearchView()
                    .environmentObject(appState)
                    .environment(\.osrsTheme, osrsTheme)
            case .article(let articleDestination):
                ArticleView(pageTitle: articleDestination.title, pageUrl: articleDestination.url)
                    .environmentObject(appState)
                    .environment(\.osrsTheme, osrsTheme)
            }
        }
    }
}

#Preview {
    NewsView()
        .environmentObject(AppState())
        .environmentObject(osrsThemeManager.preview)
        .environment(\.osrsTheme, osrsLightTheme())
}