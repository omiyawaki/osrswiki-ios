//
//  NewsViewModel.swift
//  OSRS Wiki
//
//  Created on iOS development session
//

import SwiftUI
import Combine

@MainActor
class NewsViewModel: ObservableObject {
    @Published var newsItems: [NewsItem] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    private let newsRepository = NewsRepository()
    private var cancellables = Set<AnyCancellable>()
    
    func loadNews() async {
        isLoading = true
        errorMessage = nil
        
        do {
            newsItems = try await newsRepository.fetchLatestNews()
        } catch {
            errorMessage = "Failed to load news: \(error.localizedDescription)"
            newsItems = []
        }
        
        isLoading = false
    }
    
    func refresh() async {
        await loadNews()
    }
}

// MARK: - Models
struct NewsItem: Identifiable, Codable {
    let id: String
    let title: String
    let summary: String
    let content: String?
    let imageUrl: URL?
    let publishedDate: Date
    let category: NewsCategory
    let url: URL?
    
    enum NewsCategory: String, Codable, CaseIterable {
        case update = "update"
        case announcement = "announcement"
        case popular = "popular"
        case onThisDay = "on_this_day"
        
        var displayName: String {
            switch self {
            case .update:
                return "Game Update"
            case .announcement:
                return "Announcement"
            case .popular:
                return "Popular"
            case .onThisDay:
                return "On This Day"
            }
        }
        
        var iconName: String {
            switch self {
            case .update:
                return "gamecontroller.fill"
            case .announcement:
                return "megaphone.fill"
            case .popular:
                return "flame.fill"
            case .onThisDay:
                return "calendar.circle.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .update:
                return .blue
            case .announcement:
                return .orange
            case .popular:
                return .red
            case .onThisDay:
                return .purple
            }
        }
    }
}

struct NewsCardView: View {
    let newsItem: NewsItem
    let onReadMore: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Category and date
            HStack {
                Label(newsItem.category.displayName, 
                      systemImage: newsItem.category.iconName)
                    .font(.caption)
                    .foregroundColor(newsItem.category.color)
                
                Spacer()
                
                Text(newsItem.publishedDate, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Image if available
            if let imageUrl = newsItem.imageUrl {
                AsyncImage(url: imageUrl) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .overlay(
                            ProgressView()
                        )
                }
                .frame(height: 180)
                .clipped()
                .cornerRadius(8)
            }
            
            // Title and summary
            VStack(alignment: .leading, spacing: 8) {
                Text(newsItem.title)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(3)
                
                Text(newsItem.summary)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .lineLimit(4)
            }
            
            // Read more button
            HStack {
                Spacer()
                
                Button("Read More") {
                    onReadMore()
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.accentColor)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}