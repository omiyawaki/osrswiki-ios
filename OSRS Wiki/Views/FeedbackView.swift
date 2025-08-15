//
//  FeedbackView.swift
//  OSRS Wiki
//
//  Created on iOS feature parity session
//

import SwiftUI
import MessageUI

struct FeedbackView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedFeedbackType: FeedbackType = .general
    @State private var feedbackText = ""
    @State private var userEmail = ""
    @State private var includeSystemInfo = true
    @State private var showingMailComposer = false
    @State private var showingSuccessAlert = false
    @State private var showingErrorAlert = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection
                feedbackTypeSection
                feedbackContentSection
                contactInfoSection
                systemInfoSection
                submitSection
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .navigationTitle("Send Feedback")
        .navigationBarTitleDisplayMode(.large)
        .background(appState.currentTheme.backgroundColor)
        .sheet(isPresented: $showingMailComposer) {
            if MFMailComposeViewController.canSendMail() {
                MailComposeView(
                    feedbackType: selectedFeedbackType,
                    feedbackText: feedbackText,
                    userEmail: userEmail,
                    includeSystemInfo: includeSystemInfo
                ) { result in
                    handleMailResult(result)
                }
            }
        }
        .alert("Feedback Sent", isPresented: $showingSuccessAlert) {
            Button("OK") {
                clearForm()
            }
        } message: {
            Text("Thank you for your feedback! We'll review it and get back to you if needed.")
        }
        .alert("Error", isPresented: $showingErrorAlert) {
            Button("OK") { }
        } message: {
            Text("Unable to send feedback. Please check your mail settings or try again later.")
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "envelope.fill")
                .font(.system(size: 48))
                .foregroundColor(.blue)
            
            Text("We'd love to hear from you!")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text("Help us improve the OSRS Wiki app by sharing your thoughts, reporting bugs, or suggesting new features.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private var feedbackTypeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Feedback Type")
                .font(.headline)
                .foregroundColor(.primary)
            
            ForEach(FeedbackType.allCases, id: \.self) { type in
                FeedbackTypeRow(
                    type: type,
                    isSelected: selectedFeedbackType == type
                ) {
                    selectedFeedbackType = type
                }
            }
        }
    }
    
    private var feedbackContentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Feedback")
                .font(.headline)
                .foregroundColor(.primary)
            
            TextEditor(text: $feedbackText)
                .frame(minHeight: 120)
                .padding(8)
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )
            
            Text("Please be as detailed as possible. For bugs, include steps to reproduce the issue.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var contactInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Contact Information (Optional)")
                .font(.headline)
                .foregroundColor(.primary)
            
            TextField("Your email address", text: $userEmail)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            
            Text("We'll only use this to respond to your feedback.")
                .font(.caption)
                .foregroundColor(.secondary)
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
                        .foregroundColor(.secondary)
                    
                    Text(systemInfoText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(8)
                        .background(Color(.systemGray6))
                        .cornerRadius(6)
                }
            }
            
            Text("This helps us understand and fix device-specific issues.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var submitSection: some View {
        VStack(spacing: 16) {
            Button(action: {
                submitFeedback()
            }) {
                HStack {
                    Image(systemName: "paperplane.fill")
                    Text("Send Feedback")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(isSubmitEnabled ? Color.blue : Color.gray)
                .cornerRadius(12)
            }
            .disabled(!isSubmitEnabled)
            
            Button("Clear Form") {
                clearForm()
            }
            .foregroundColor(.red)
            .font(.body)
        }
    }
    
    private var isSubmitEnabled: Bool {
        !feedbackText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private var systemInfoText: String {
        let device = UIDevice.current
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        
        return """
        App Version: \(appVersion) (\(buildNumber))
        iOS Version: \(device.systemVersion)
        Device: \(device.model)
        Theme: \(appState.currentTheme.rawValue)
        """
    }
    
    private func submitFeedback() {
        if MFMailComposeViewController.canSendMail() {
            showingMailComposer = true
        } else {
            // Fallback to opening mail app or showing alternative
            openMailApp()
        }
    }
    
    private func openMailApp() {
        let subject = "OSRS Wiki iOS App - \(selectedFeedbackType.displayName)"
        let body = createEmailBody()
        
        if let emailURL = URL(string: "mailto:feedback@osrswiki.app?subject=\(subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&body=\(body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") {
            UIApplication.shared.open(emailURL)
        } else {
            showingErrorAlert = true
        }
    }
    
    private func createEmailBody() -> String {
        var body = feedbackText + "\n\n"
        
        if !userEmail.isEmpty {
            body += "Contact: \(userEmail)\n\n"
        }
        
        if includeSystemInfo {
            body += "---\nSystem Information:\n\(systemInfoText)"
        }
        
        return body
    }
    
    private func handleMailResult(_ result: MFMailComposeResult) {
        showingMailComposer = false
        
        switch result {
        case .sent:
            showingSuccessAlert = true
        case .failed:
            showingErrorAlert = true
        default:
            break
        }
    }
    
    private func clearForm() {
        feedbackText = ""
        userEmail = ""
        selectedFeedbackType = .general
        includeSystemInfo = true
    }
}

struct FeedbackTypeRow: View {
    let type: FeedbackType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: type.iconName)
                    .foregroundColor(type.color)
                    .frame(width: 24, height: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(type.displayName)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(type.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                }
            }
            .padding()
            .background(isSelected ? Color.blue.opacity(0.1) : Color(.systemGray6))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
    }
}

// MARK: - FeedbackType Enum
enum FeedbackType: CaseIterable {
    case bug, feature, general, complaint
    
    var displayName: String {
        switch self {
        case .bug: return "Bug Report"
        case .feature: return "Feature Request"
        case .general: return "General Feedback"
        case .complaint: return "Issue/Complaint"
        }
    }
    
    var description: String {
        switch self {
        case .bug: return "Report something that's not working correctly"
        case .feature: return "Suggest a new feature or improvement"
        case .general: return "Share your thoughts about the app"
        case .complaint: return "Report an issue or problem with the app"
        }
    }
    
    var iconName: String {
        switch self {
        case .bug: return "ant.fill"
        case .feature: return "lightbulb.fill"
        case .general: return "bubble.left.fill"
        case .complaint: return "exclamationmark.triangle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .bug: return .red
        case .feature: return .yellow
        case .general: return .blue
        case .complaint: return .orange
        }
    }
}

// MARK: - Mail Composer Wrapper
struct MailComposeView: UIViewControllerRepresentable {
    let feedbackType: FeedbackType
    let feedbackText: String
    let userEmail: String
    let includeSystemInfo: Bool
    let completion: (MFMailComposeResult) -> Void
    
    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let composer = MFMailComposeViewController()
        composer.mailComposeDelegate = context.coordinator
        
        composer.setToRecipients(["feedback@osrswiki.app"])
        composer.setSubject("OSRS Wiki iOS App - \(feedbackType.displayName)")
        
        var body = feedbackText + "\n\n"
        
        if !userEmail.isEmpty {
            body += "Contact: \(userEmail)\n\n"
        }
        
        if includeSystemInfo {
            let device = UIDevice.current
            let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
            let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
            
            body += """
            ---
            System Information:
            App Version: \(appVersion) (\(buildNumber))
            iOS Version: \(device.systemVersion)
            Device: \(device.model)
            """
        }
        
        composer.setMessageBody(body, isHTML: false)
        
        return composer
    }
    
    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {
        // No updates needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(completion: completion)
    }
    
    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let completion: (MFMailComposeResult) -> Void
        
        init(completion: @escaping (MFMailComposeResult) -> Void) {
            self.completion = completion
        }
        
        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            completion(result)
        }
    }
}

#Preview {
    NavigationView {
        FeedbackView()
            .environmentObject(AppState())
    }
}