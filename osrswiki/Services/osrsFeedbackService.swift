//
//  osrsFeedbackService.swift
//  OSRS Wiki
//
//  Created for iOS feedback parity implementation
//

import Foundation
import UIKit

/// Service for securely submitting feedback via Google Cloud Function.
/// This approach keeps the GitHub API token secure on the server side and routes
/// iOS feedback to the appropriate repository (osrswiki-ios).
class osrsFeedbackService {
    
    static let shared = osrsFeedbackService()
    
    private let cloudFunctionURL = "https://us-central1-osrs-459713.cloudfunctions.net/createGithubIssue"
    private let session = URLSession.shared
    
    private init() {}
    
    /// Creates a bug report issue via secure Cloud Function
    func reportIssue(title: String, description: String) async -> Result<String, Error> {
        return await submitFeedback(title: title, description: description, label: "bug")
    }
    
    /// Creates a feature request issue via secure Cloud Function
    func requestFeature(title: String, description: String) async -> Result<String, Error> {
        return await submitFeedback(title: title, description: description, label: "enhancement")
    }
    
    /// Creates a general feedback issue via secure Cloud Function
    func submitGeneralFeedback(title: String, description: String) async -> Result<String, Error> {
        return await submitFeedback(title: title, description: description, label: "feedback")
    }
    
    private func submitFeedback(title: String, description: String, label: String) async -> Result<String, Error> {
        do {
            let deviceInfo = getDeviceInfo()
            let fullBody = """
            \(description)
            
            ---
            **Device Information:**
            \(deviceInfo)
            """
            
            let requestBody = osrsCloudFunctionIssueRequest(
                title: title,
                body: fullBody,
                labels: [label],
                platform: "ios"
            )
            
            let jsonData = try JSONEncoder().encode(requestBody)
            
            guard let url = URL(string: cloudFunctionURL) else {
                return .failure(osrsFeedbackError.invalidURL)
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("OSRSWikiApp-iOS/\(getAppVersion())", forHTTPHeaderField: "User-Agent")
            request.httpBody = jsonData
            
            print("osrsFeedbackService: Submitting feedback via Cloud Function for iOS")
            
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                return .failure(osrsFeedbackError.invalidResponse)
            }
            
            switch httpResponse.statusCode {
            case 200:
                if let responseData = try? JSONDecoder().decode(osrsCloudFunctionResponse.self, from: data) {
                    print("osrsFeedbackService: Feedback submitted successfully: \(responseData.message)")
                    return .success("Your feedback has been submitted successfully!")
                } else {
                    return .success("Your feedback has been submitted successfully!")
                }
            case 400:
                return .failure(osrsFeedbackError.invalidRequest)
            case 500:
                return .failure(osrsFeedbackError.serverError)
            default:
                return .failure(osrsFeedbackError.httpError(httpResponse.statusCode))
            }
            
        } catch {
            print("osrsFeedbackService: Error submitting feedback - \(error)")
            
            if let urlError = error as? URLError {
                switch urlError.code {
                case .notConnectedToInternet:
                    return .failure(osrsFeedbackError.noInternetConnection)
                case .timedOut:
                    return .failure(osrsFeedbackError.timeout)
                default:
                    return .failure(osrsFeedbackError.networkError(urlError))
                }
            } else {
                return .failure(osrsFeedbackError.unexpectedError(error))
            }
        }
    }
    
    private func getDeviceInfo() -> String {
        let device = UIDevice.current
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        
        return """
        - App Version: \(appVersion) (\(buildNumber))
        - iOS Version: \(device.systemVersion)
        - Device: \(device.model)
        - Device Name: \(device.name)
        - System Name: \(device.systemName)
        """
    }
    
    private func getAppVersion() -> String {
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(appVersion).\(buildNumber)"
    }
}

// MARK: - Data Models

struct osrsCloudFunctionIssueRequest: Codable {
    let title: String
    let body: String
    let labels: [String]?
    let platform: String
}

struct osrsCloudFunctionResponse: Codable {
    let message: String
}

// MARK: - Error Types

enum osrsFeedbackError: Error, LocalizedError {
    case invalidURL
    case invalidRequest
    case serverError
    case httpError(Int)
    case invalidResponse
    case noInternetConnection
    case timeout
    case networkError(URLError)
    case unexpectedError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid feedback service URL"
        case .invalidRequest:
            return "Invalid request. Please check your input."
        case .serverError:
            return "Server error. Please try again later."
        case .httpError(let code):
            return "Failed to submit feedback: HTTP \(code)"
        case .invalidResponse:
            return "Invalid response from server"
        case .noInternetConnection:
            return "No internet connection. Please check your network."
        case .timeout:
            return "Request timed out. Please try again."
        case .networkError(let urlError):
            return "Network error: \(urlError.localizedDescription)"
        case .unexpectedError(let error):
            return "Unexpected error: \(error.localizedDescription)"
        }
    }
}