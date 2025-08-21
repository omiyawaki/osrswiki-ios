//
//  DonateView.swift
//  OSRS Wiki
//
//  Created on iOS feature parity session
//

import SwiftUI
import StoreKit
import PassKit

struct DonateView: View {
    @EnvironmentObject var themeManager: osrsThemeManager
    @Environment(\.osrsTheme) var osrsTheme
    @StateObject private var donationManager = DonationManager()
    @State private var selectedAmount: DonationAmount?
    @State private var customAmount: String = ""
    @State private var showingCustomInput = false
    @State private var showingProcessing = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection
                amountSelectionSection
                
                if showingCustomInput {
                    customAmountSection
                }
                
                donateButtonSection
                
                if showingProcessing {
                    processingSection
                }
                
                wikiSupportSection
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .navigationTitle("Donate")
        .navigationBarTitleDisplayMode(.inline)
        .background(.osrsBackground)
        .onAppear {
            donationManager.loadProducts()
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "heart.fill")
                .font(.system(size: 48))
                .foregroundStyle(.osrsError)
            
            Text("Support OSRS Wiki")
                .font(.title)
                .fontWeight(.bold)
                .foregroundStyle(.osrsPrimaryTextColor)
            
            Text("Help keep this app free and ad-free! Your support helps us continue improving the app and adding new features for the OSRS community.")
                .font(.body)
                .foregroundStyle(.osrsSecondaryTextColor)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
        }
    }
    
    private var amountSelectionSection: some View {
        VStack(spacing: 12) {
            Text("Choose an amount")
                .font(.headline)
                .foregroundStyle(.osrsPrimaryTextColor)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                ForEach(DonationAmount.allCases.filter { $0 != .custom }, id: \.self) { amount in
                    DonationAmountButton(
                        amount: amount,
                        isSelected: selectedAmount == amount
                    ) {
                        selectedAmount = amount
                        showingCustomInput = false
                        customAmount = ""
                    }
                }
            }
            
            DonationAmountButton(
                amount: .custom,
                isSelected: showingCustomInput
            ) {
                showingCustomInput = true
                selectedAmount = .custom
            }
        }
    }
    
    private var customAmountSection: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "dollarsign.circle.fill")
                    .foregroundStyle(.osrsAccent)
                
                TextField("Enter amount", text: $customAmount)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            
            Text("Minimum: $1.00, Maximum: $99.99")
                .font(.caption)
                .foregroundStyle(.osrsSecondaryTextColor)
        }
        .padding()
        .background(.osrsSearchBoxBackgroundColor)
        .cornerRadius(12)
    }
    
    private var donateButtonSection: some View {
        VStack(spacing: 12) {
            Button(action: {
                processDonation()
            }) {
                HStack {
                    Image(systemName: "heart.fill")
                    Text(donateButtonText)
                }
                .font(.headline)
                .foregroundStyle(.osrsOnPrimary)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(osrsTheme.primary))
                .cornerRadius(12)
            }
            .disabled(!isDonateButtonEnabled)
            .opacity(isDonateButtonEnabled ? 1.0 : 0.4)
            
        }
    }
    
    private var processingSection: some View {
        VStack(spacing: 8) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Processing payment...")
                .font(.body)
                .foregroundStyle(.osrsSecondaryTextColor)
        }
        .padding()
        .background(.osrsSearchBoxBackgroundColor)
        .cornerRadius(12)
    }
    
    private var wikiSupportSection: some View {
        VStack(spacing: 16) {
            Divider()
            
            VStack(spacing: 12) {
                Text("Support the Wiki Too!")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.osrsPrimaryTextColor)
                
                Text("The Old School RuneScape Wiki is maintained by volunteers. Consider supporting them too!")
                    .font(.body)
                    .foregroundStyle(.osrsSecondaryTextColor)
                    .multilineTextAlignment(.center)
                
                Button(action: {
                    openWikiDonation()
                }) {
                    HStack {
                        Text("Donate to Wiki")
                        Image(systemName: "arrow.up.right")
                    }
                    .font(.headline)
                    .foregroundStyle(.osrsPrimary)
                    .padding()
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(.osrsOutline, lineWidth: 2)
                    )
                }
            }
        }
    }
    
    private var isDonateButtonEnabled: Bool {
        if showingCustomInput {
            guard let amount = Double(customAmount), amount >= 1.00, amount <= 99.99 else {
                return false
            }
        }
        return selectedAmount != nil && !showingProcessing
    }
    
    private var donateButtonText: String {
        if let selectedAmount = selectedAmount {
            switch selectedAmount {
            case .custom:
                if let amount = Double(customAmount), amount >= 1.00 {
                    return String(format: "Donate $%.2f", amount)
                } else {
                    return "Enter Amount"
                }
            default:
                return "Donate \(selectedAmount.displayValue)"
            }
        }
        return "Select Amount"
    }
    
    private func processDonation() {
        guard donationManager.isApplePayAvailable else {
            // Show alert that Apple Pay is not available
            return
        }
        
        showingProcessing = true
        
        let amount: Double
        if selectedAmount == .custom {
            amount = Double(customAmount) ?? 0
        } else {
            amount = selectedAmount?.value ?? 0
        }
        
        donationManager.processDonation(amount: amount) { success in
            DispatchQueue.main.async {
                showingProcessing = false
                if success {
                    // Show success message
                    selectedAmount = nil
                    customAmount = ""
                    showingCustomInput = false
                }
            }
        }
    }
    
    private func openWikiDonation() {
        if let url = URL(string: "https://oldschool.runescape.wiki/w/RuneScape:Donate") {
            UIApplication.shared.open(url)
        }
    }
}

struct DonationAmountButton: View {
    @Environment(\.osrsTheme) var osrsTheme
    let amount: DonationAmount
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(amount.displayValue)
                .font(.headline)
                .foregroundStyle(isSelected ? .osrsOnPrimary : .osrsPrimaryTextColor)
                .frame(maxWidth: .infinity)
                .padding()
                .background(isSelected ? .osrsPrimary : .osrsSearchBoxBackgroundColor)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? Color(osrsTheme.outline) : Color.clear, lineWidth: 2)
                )
        }
    }
}

// MARK: - DonationAmount Enum
enum DonationAmount: CaseIterable {
    case one, five, ten, twentyFive, custom
    
    var displayValue: String {
        switch self {
        case .one: return "$1"
        case .five: return "$5"
        case .ten: return "$10"
        case .twentyFive: return "$25"
        case .custom: return "Custom"
        }
    }
    
    var value: Double {
        switch self {
        case .one: return 1.0
        case .five: return 5.0
        case .ten: return 10.0
        case .twentyFive: return 25.0
        case .custom: return 0.0
        }
    }
}

// MARK: - DonationManager
class DonationManager: NSObject, ObservableObject {
    @Published var products: [SKProduct] = [] // Legacy StoreKit for compatibility
    @Published var canMakePayments: Bool = {
        if #available(iOS 18.0, *) {
            return true // AppStore.canMakePayments would go here when using modern StoreKit
        } else {
            return SKPaymentQueue.canMakePayments()
        }
    }()
    @Published var isApplePayAvailable = PKPaymentAuthorizationViewController.canMakePayments()
    
    private var donationCompletion: ((Bool) -> Void)?
    
    func loadProducts() {
        // TODO: Implement StoreKit product loading for in-app purchases
        // This would load donation products from App Store Connect
    }
    
    func processDonation(amount: Double, completion: @escaping (Bool) -> Void) {
        guard PKPaymentAuthorizationViewController.canMakePayments() else {
            completion(false)
            return
        }
        
        self.donationCompletion = completion
        
        let request = PKPaymentRequest()
        request.merchantIdentifier = "merchant.com.omiyawaki.osrswiki" 
        request.supportedNetworks = [.visa, .masterCard, .amex, .discover]
        request.merchantCapabilities = .threeDSecure
        request.countryCode = "US"
        request.currencyCode = "USD"
        
        let paymentItem = PKPaymentSummaryItem(
            label: "OSRS Wiki Donation",
            amount: NSDecimalNumber(value: amount)
        )
        request.paymentSummaryItems = [paymentItem]
        
        guard let authorizationViewController = PKPaymentAuthorizationViewController(paymentRequest: request) else {
            completion(false)
            return
        }
        
        authorizationViewController.delegate = self
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController {
            
            var topViewController = rootViewController
            while let presentedViewController = topViewController.presentedViewController {
                topViewController = presentedViewController
            }
            
            topViewController.present(authorizationViewController, animated: true)
        }
    }
}

// MARK: - PKPaymentAuthorizationViewControllerDelegate
extension DonationManager: PKPaymentAuthorizationViewControllerDelegate {
    func paymentAuthorizationViewController(
        _ controller: PKPaymentAuthorizationViewController,
        didAuthorizePayment payment: PKPayment,
        handler completion: @escaping (PKPaymentAuthorizationResult) -> Void
    ) {
        // Process the payment with your backend
        // For demo purposes, we'll simulate success
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            completion(PKPaymentAuthorizationResult(status: .success, errors: nil))
            self.donationCompletion?(true)
            self.donationCompletion = nil
        }
    }
    
    func paymentAuthorizationViewControllerDidFinish(_ controller: PKPaymentAuthorizationViewController) {
        controller.dismiss(animated: true)
        // If donation completion hasn't been called yet (user cancelled), call it with false
        if let completion = donationCompletion {
            completion(false)
            donationCompletion = nil
        }
    }
}

#Preview {
    NavigationView {
        DonateView()
            .environmentObject(osrsThemeManager.preview)
            .environment(\.osrsTheme, osrsLightTheme())
    }
}