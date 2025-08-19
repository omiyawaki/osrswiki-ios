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
    @State private var showingSearchModal = false
    
    var body: some View {
        NavigationStack(path: $appState.navigationPath) {
            VStack(spacing: 0) {
                // Custom header matching Android
                HeaderView()
                
                ScrollView {
                    LazyVStack(spacing: 16) {
                        // Search bar at top (matches Android)
                        SearchBarView(placeholder: "Search OSRS Wiki") {
                            // Show DedicatedSearchView modal (matches Android SearchActivity)
                            showingSearchModal = true
                        }
                        .padding(.horizontal)
                        
                        // Feed content matching Android structure
                        if viewModel.isLoading {
                            ProgressView("Loading news...")
                                .frame(maxWidth: .infinity, minHeight: 200)
                        } else if let wikiFeed = viewModel.wikiFeed {
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
            .navigationTitle("")
            .navigationBarHidden(true)
            .refreshable {
                await viewModel.refresh()
            }
            .background(.osrsBackground)
            .navigationDestination(for: ArticleDestination.self) { destination in
                ArticleView(pageTitle: destination.title, pageUrl: destination.url)
            }
            .fullScreenCover(isPresented: $showingSearchModal) {
                // Dedicated search modal (matches Android SearchActivity behavior)
                DedicatedSearchView(isPresented: $showingSearchModal)
                    .environmentObject(appState)
                    .environmentObject(themeManager)
                    .environment(\.osrsTheme, osrsTheme)
                    .onAppear {
                        print("🔍 DedicatedSearchView appeared in fullScreenCover")
                        NSLog("🔍 DedicatedSearchView appeared in fullScreenCover")
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
                    .foregroundStyle(.osrsOnSurfaceVariant)
                    .font(.system(size: 16, weight: .medium))
                
                Text(placeholder)
                    .foregroundStyle(.osrsOnSurfaceVariant)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // Voice search icon on the far right (matches Android)
                Image(systemName: "mic")
                    .foregroundStyle(.osrsOnSurfaceVariant)
                    .font(.system(size: 16, weight: .medium))
            }
            .padding()
            .background(.osrsSurfaceVariant)
            .cornerRadius(10)
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
                .foregroundStyle(.osrsOnSurfaceVariant)
            
            VStack(spacing: 8) {
                Text(title)
                    .font(.osrsHeadline)
                    .foregroundStyle(.osrsOnSurface)
                
                Text(subtitle)
                    .font(.osrsBody)
                    .foregroundStyle(.osrsOnSurfaceVariant)
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
                .foregroundStyle(.osrsOnSurface)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Random page button (matching Android)
            Button(action: {
                // TODO: Implement random page navigation
                print("Random page button tapped")
            }) {
                Image(systemName: "shuffle")
                    .font(.system(size: 24))
                    .foregroundStyle(.osrsOnSurfaceVariant)
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
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                // Image section
                AsyncImage(url: URL(string: updateItem.imageUrl)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(.osrsSurfaceVariant)
                        .overlay(
                            ProgressView()
                                .tint(Color.osrsAccentColor)
                        )
                }
                .frame(width: 280, height: 140)
                .clipped()
                
                // Content section
                VStack(alignment: .leading, spacing: 8) {
                    Text(updateItem.title)
                        .font(.osrsTitle)
                        .foregroundStyle(.osrsOnSurface)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text(updateItem.snippet)
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
        .background(.osrsSurface)
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
        VStack(alignment: .leading, spacing: 8) {
            // Section header
            Text("Announcements")
                .font(.osrsSectionHeaderSmallCaps)
                .foregroundStyle(.osrsOnSurface)
                .textCase(.uppercase)
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
            .background(.osrsSurface)
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
        VStack(alignment: .leading, spacing: 8) {
            // Section header
            Text(onThisDayItem.title)
                .font(.osrsSectionHeaderSmallCaps)
                .foregroundStyle(.osrsOnSurface)
                .textCase(.uppercase)
                .kerning(0.5)
                .padding(.horizontal, 16)
            
            // Card content
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(onThisDayItem.events.enumerated()), id: \.offset) { index, event in
                    HTMLTextView("• \(event)") { url in
                        onLinkTap(url.absoluteString)
                    }
                    .font(.osrsBody)
                    .foregroundStyle(.osrsOnSurface)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.osrsSurface)
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
        VStack(alignment: .leading, spacing: 8) {
            // Section header
            Text("Popular pages")
                .font(.osrsSectionHeaderSmallCaps)
                .foregroundStyle(.osrsOnSurface)
                .textCase(.uppercase)
                .kerning(0.5)
                .padding(.horizontal, 16)
            
            // Card content
            VStack(alignment: .leading, spacing: 8) {
                ForEach(popularPages) { page in
                    Button(action: { onLinkTap(page.pageUrl) }) {
                        Text(page.title)
                            .font(.osrsBody)
                            .foregroundStyle(.osrsAccent)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.osrsSurface)
            .cornerRadius(8)
            .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
            .shadow(color: .black.opacity(0.16), radius: 1, x: 0, y: 1)
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 8)
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
            
            // Override HTML fonts with system fonts
            let range = NSRange(location: 0, length: attributedString.length)
            let systemFont = UIFont.systemFont(ofSize: 16) // Match .osrsBody size
            
            // Remove any existing font attributes and apply system font
            attributedString.removeAttribute(.font, range: range)
            attributedString.addAttribute(.font, value: systemFont, range: range)
            
            return attributedString
        } catch {
            print("Error parsing HTML: \(error)")
            return nil
        }
    }
}

#Preview {
    NewsView()
        .environmentObject(AppState())
        .environmentObject(osrsThemeManager.preview)
        .environment(\.osrsTheme, osrsLightTheme())
}