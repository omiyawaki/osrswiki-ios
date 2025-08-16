//
//  DonateView.swift
//  OSRS Wiki
//
//  Created on iOS feature parity session
//

import SwiftUI
import StoreKit

struct DonateView: View {
    @EnvironmentObject var themeManager: OSRSThemeManager
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
        .navigationTitle("Support Development")
        .navigationBarTitleDisplayMode(.large)
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
                .foregroundStyle(.osrsOnSurface)
            
            Text("Help keep this app free and ad-free! Your support helps us continue improving the app and adding new features for the OSRS community.")
                .font(.body)
                .foregroundStyle(.osrsOnSurfaceVariant)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
        }
    }
    
    private var amountSelectionSection: some View {
        VStack(spacing: 12) {
            Text("Choose an amount")
                .font(.headline)
                .foregroundStyle(.osrsOnSurface)
            
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
                .foregroundStyle(.osrsOnSurfaceVariant)
        }
        .padding()
        .background(.osrsSurfaceVariant)
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
                .background(isDonateButtonEnabled ? .osrsPrimary : .osrsOnSurfaceVariant)
                .cornerRadius(12)
            }
            .disabled(!isDonateButtonEnabled)
            
            Text("Secure payment powered by Apple Pay")
                .font(.caption)
                .foregroundStyle(.osrsOnSurfaceVariant)
            
            HStack(spacing: 20) {
                Image(systemName: "lock.shield.fill")
                    .foregroundStyle(.osrsAccent)
                Text("Secure")
                
                Image(systemName: "creditcard.fill")
                    .foregroundStyle(.osrsPrimary)
                Text("Apple Pay")
                
                Image(systemName: "checkmark.shield.fill")
                    .foregroundStyle(.osrsAccent)
                Text("Safe")
            }
            .font(.caption)
            .foregroundStyle(.osrsOnSurfaceVariant)
        }
    }
    
    private var processingSection: some View {
        VStack(spacing: 8) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Processing payment...")
                .font(.body)
                .foregroundStyle(.osrsOnSurfaceVariant)
        }
        .padding()
        .background(.osrsSurfaceVariant)
        .cornerRadius(12)
    }
    
    private var wikiSupportSection: some View {
        VStack(spacing: 16) {
            Divider()
            
            VStack(spacing: 12) {
                Text("Support the Wiki Too!")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.osrsOnSurface)
                
                Text("The Old School RuneScape Wiki is maintained by volunteers. Consider supporting them too!")
                    .font(.body)
                    .foregroundStyle(.osrsOnSurfaceVariant)
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
                            .stroke(.osrsPrimary, lineWidth: 2)
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
    let amount: DonationAmount
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(amount.displayValue)
                .font(.headline)
                .foregroundStyle(isSelected ? .osrsOnPrimary : .osrsOnSurface)
                .frame(maxWidth: .infinity)
                .padding()
                .background(isSelected ? .osrsPrimary : .osrsSurfaceVariant)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? .osrsPrimaryColor : Color.clear, lineWidth: 2)
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
class DonationManager: ObservableObject {
    @Published var products: [SKProduct] = []
    @Published var canMakePayments = SKPaymentQueue.canMakePayments()
    
    func loadProducts() {
        // TODO: Implement StoreKit product loading for in-app purchases
        // This would load donation products from App Store Connect
    }
    
    func processDonation(amount: Double, completion: @escaping (Bool) -> Void) {
        // TODO: Implement actual donation processing through StoreKit
        // For now, simulate processing
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            completion(true)
        }
    }
}

#Preview {
    NavigationView {
        DonateView()
            .environmentObject(OSRSThemeManager.preview)
            .environment(\.osrsTheme, OSRSLightTheme())
    }
}