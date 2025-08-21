//
//  FeedbackView.swift
//  OSRS Wiki
//
//  Created on iOS feature parity session - Updated for design and functional parity with Android
//

import SwiftUI
import MessageUI

struct FeedbackView: View {
    @EnvironmentObject var themeManager: osrsThemeManager
    @Environment(\.osrsTheme) var osrsTheme
    @State private var showingBugReportForm = false
    @State private var showingFeatureRequestForm = false
    @State private var showingSuccessAlert = false
    @State private var showingErrorAlert = false
    @State private var alertMessage = ""
    @State private var isSubmitting = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                rateAppCard
                reportIssueCard
                requestFeatureCard
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .navigationTitle("Send Feedback")
        .navigationBarTitleDisplayMode(.inline)
        .background(.osrsBackground)
        .sheet(isPresented: $showingBugReportForm) {
            osrsFeedbackFormView(
                feedbackType: .bug,
                isPresented: $showingBugReportForm,
                onSuccess: { message in
                    alertMessage = message
                    showingSuccessAlert = true
                },
                onError: { error in
                    alertMessage = error
                    showingErrorAlert = true
                }
            )
        }
        .sheet(isPresented: $showingFeatureRequestForm) {
            osrsFeedbackFormView(
                feedbackType: .feature,
                isPresented: $showingFeatureRequestForm,
                onSuccess: { message in
                    alertMessage = message
                    showingSuccessAlert = true
                },
                onError: { error in
                    alertMessage = error
                    showingErrorAlert = true
                }
            )
        }
        .alert("Success", isPresented: $showingSuccessAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
        .alert("Error", isPresented: $showingErrorAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private var headerSection: some View {
        Text("Help & Feedback")
            .font(.title)
            .fontWeight(.bold)
            .foregroundStyle(.osrsPrimaryTextColor)
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)
            .padding(.bottom, 8)
    }
    
    // MARK: - Feedback Cards (Android Design Parity)
    
    private var rateAppCard: some View {
        VStack {
            osrsFeedbackCardView(
                title: "Rate This App",
                description: "Love our app? Rate it on the App Store to help others discover it!",
                buttonText: "Rate App",
                buttonIcon: "arrow.up.right",
                action: {
                    openAppStore()
                }
            )
        }
    }
    
    private var reportIssueCard: some View {
        VStack {
            osrsFeedbackCardView(
                title: "Report an Issue",
                description: "Found a bug or something not working correctly? Let us know!",
                buttonText: "Report Issue",
                buttonIcon: "ant.fill",
                action: {
                    showingBugReportForm = true
                }
            )
        }
    }
    
    private var requestFeatureCard: some View {
        VStack {
            osrsFeedbackCardView(
                title: "Request a Feature",
                description: "Have an idea for a new feature or improvement? Share it with us!",
                buttonText: "Request Feature",
                buttonIcon: "lightbulb.fill",
                action: {
                    showingFeatureRequestForm = true
                }
            )
        }
    }
    
    // MARK: - Actions
    
    private func openAppStore() {
        // Open App Store rating page for the app
        if let url = URL(string: "https://apps.apple.com/app/idYOUR_APP_ID?action=write-review") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Reusable Card Component (Android Design Parity)

struct osrsFeedbackCardView: View {
    let title: String
    let description: String
    let buttonText: String
    let buttonIcon: String
    let action: () -> Void
    
    @Environment(\.osrsTheme) var osrsTheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.osrsPrimaryTextColor)
                
                Text(description)
                    .font(.body)
                    .foregroundStyle(.osrsSecondaryTextColor)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Button(action: action) {
                HStack(spacing: 8) {
                    Image(systemName: buttonIcon)
                    Text(buttonText)
                }
                .font(.callout)
                .fontWeight(.medium)
                .foregroundStyle(.osrsPrimary)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.osrsSearchBoxBackgroundColor)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.clear, lineWidth: 0)
        )
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Feedback Form Component

struct osrsFeedbackFormView: View {
    let feedbackType: osrsFeedbackType
    @Binding var isPresented: Bool
    let onSuccess: (String) -> Void
    let onError: (String) -> Void
    
    @State private var title = ""
    @State private var description = ""
    @State private var useCase = "" // Only for feature requests
    @State private var includeSystemInfo = true
    @State private var isSubmitting = false
    
    @Environment(\.osrsTheme) var osrsTheme
    @EnvironmentObject var themeManager: osrsThemeManager
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    titleSection
                    descriptionSection
                    if feedbackType == .feature {
                        useCaseSection
                    }
                    systemInfoSection
                    submitButton
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
            .navigationTitle(feedbackType.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .foregroundStyle(.osrsPrimary)
                }
            }
            .background(.osrsBackground)
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            Image(systemName: feedbackType.iconName)
                .font(.system(size: 48))
                .foregroundStyle(feedbackType.color)
            
            Text(feedbackType.description)
                .font(.body)
                .foregroundStyle(.osrsSecondaryTextColor)
                .multilineTextAlignment(.center)
        }
        .padding(.top, -8)
        .padding(.bottom, 4)
    }
    
    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(feedbackType == .feature ? "Feature Summary" : "Title")
                .font(.headline)
                .foregroundStyle(.osrsPrimaryTextColor)
            
            TextField(
                feedbackType == .feature ? 
                "Brief description of the feature you'd like to see" : 
                "Brief description of the \(feedbackType.displayName.lowercased())", 
                text: $title
            )
                .padding()
                .background(.osrsSearchBoxBackgroundColor)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(.osrsOutline, lineWidth: 1)
                )
        }
    }
    
    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(feedbackType == .feature ? "Detailed Description" : "Description")
                .font(.headline)
                .foregroundStyle(.osrsPrimaryTextColor)
            
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.osrsSearchBoxBackgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(.osrsOutline, lineWidth: 1)
                    )
                
                TextEditor(text: $description)
                    .padding(8)
                    .background(Color.clear)
                    .scrollContentBackground(.hidden)
                    .foregroundStyle(.osrsPrimaryTextColor)
            }
            .frame(minHeight: 120)
            
            Text(feedbackType == .bug ? 
                 "Please include steps to reproduce the issue." : 
                 feedbackType == .feature ?
                 "Describe exactly what the feature should do and how it should work" :
                 "Describe your idea in as much detail as possible.")
                .font(.caption)
                .foregroundStyle(.osrsSecondaryTextColor)
        }
    }
    
    private var useCaseSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Use Case (Optional)")
                .font(.headline)
                .foregroundStyle(.osrsPrimaryTextColor)
            
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.osrsSearchBoxBackgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(.osrsOutline, lineWidth: 1)
                    )
                
                TextEditor(text: $useCase)
                    .padding(8)
                    .background(Color.clear)
                    .scrollContentBackground(.hidden)
                    .foregroundStyle(.osrsPrimaryTextColor)
            }
            .frame(minHeight: 80)
            
            Text("Explain why this feature would be valuable and how you'd use it")
                .font(.caption)
                .foregroundStyle(.osrsSecondaryTextColor)
        }
    }
    
    private var systemInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Include system information", isOn: $includeSystemInfo)
                .font(.headline)
            
            if includeSystemInfo {
                VStack(alignment: .leading, spacing: 4) {
                    Text("System Information:")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.osrsSecondaryTextColor)
                    
                    Text(systemInfoText)
                        .font(.caption)
                        .foregroundStyle(.osrsSecondaryTextColor)
                        .padding(8)
                        .background(.osrsSearchBoxBackgroundColor)
                        .cornerRadius(6)
                }
            }
            
            Text("This helps us understand and fix device-specific issues.")
                .font(.caption)
                .foregroundStyle(.osrsSecondaryTextColor)
        }
    }
    
    private var submitButton: some View {
        Button(action: {
            submitFeedback()
        }) {
            HStack {
                if isSubmitting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Color.osrsOnPrimaryColor))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "paperplane.fill")
                }
                Text(isSubmitting ? "Submitting..." : "Submit \(feedbackType.displayName)")
            }
            .font(.headline)
            .foregroundStyle(.osrsOnPrimary)
            .frame(maxWidth: .infinity)
            .padding()
            .background(.osrsPrimary)
            .opacity(isSubmitEnabled ? 1.0 : 0.4)
            .cornerRadius(12)
        }
        .disabled(!isSubmitEnabled || isSubmitting)
    }
    
    private var isSubmitEnabled: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private var systemInfoText: String {
        let device = UIDevice.current
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        
        return """
        App Version: \(appVersion) (\(buildNumber))
        iOS Version: \(device.systemVersion)
        Device: \(device.model)
        Theme: \(themeManager.selectedTheme.rawValue)
        """
    }
    
    private func submitFeedback() {
        isSubmitting = true
        
        Task {
            let result: Result<String, Error>
            
            switch feedbackType {
            case .bug:
                result = await osrsFeedbackService.shared.reportIssue(title: title, description: description)
            case .feature:
                // Combine description and use case if provided (matching Android logic)
                let fullDescription = if !useCase.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    "\(description)\n\n**Use Case:**\n\(useCase)"
                } else {
                    description
                }
                result = await osrsFeedbackService.shared.requestFeature(title: title, description: fullDescription)
            }
            
            await MainActor.run {
                isSubmitting = false
                
                switch result {
                case .success(let message):
                    onSuccess(message)
                    isPresented = false
                case .failure(let error):
                    if let feedbackError = error as? osrsFeedbackError {
                        onError(feedbackError.localizedDescription)
                    } else {
                        onError("An unexpected error occurred: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
}

// MARK: - Feedback Type Enum
enum osrsFeedbackType {
    case bug, feature
    
    var displayName: String {
        switch self {
        case .bug: return "Bug Report"
        case .feature: return "Feature Request"
        }
    }
    
    var description: String {
        switch self {
        case .bug: return "Report something that's not working correctly"
        case .feature: return "Suggest a new feature or improvement"
        }
    }
    
    var iconName: String {
        switch self {
        case .bug: return "ant.fill"
        case .feature: return "lightbulb.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .bug: return Color.osrsErrorColor
        case .feature: return Color.osrsAccentColor
        }
    }
}

#Preview {
    NavigationView {
        FeedbackView()
            .environmentObject(AppState())
            .environmentObject(osrsThemeManager.preview)
            .environment(\.osrsTheme, osrsLightTheme())
    }
}