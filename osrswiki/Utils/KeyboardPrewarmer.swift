//
//  KeyboardPrewarmer.swift
//  OSRS Wiki
//
//  Pre-warms the keyboard to eliminate first-show latency
//

import SwiftUI
import UIKit

class KeyboardPrewarmer {
    static let shared = KeyboardPrewarmer()
    private var hiddenTextField: UITextField?
    private var hasPrewarmed = false
    
    private init() {}
    
    /// Pre-warm the keyboard on app launch to eliminate first-show delay
    func prewarmKeyboard() {
        guard !hasPrewarmed else { return }
        hasPrewarmed = true
        
        DispatchQueue.main.async { [weak self] in
            // Create a hidden text field
            let textField = UITextField()
            textField.frame = CGRect(x: -100, y: -100, width: 1, height: 1)
            textField.alpha = 0
            
            // Add to the window
            if let window = UIApplication.shared.windows.first {
                window.addSubview(textField)
                
                // Show keyboard briefly
                textField.becomeFirstResponder()
                
                // Hide it after a minimal delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    textField.resignFirstResponder()
                    textField.removeFromSuperview()
                    self?.hiddenTextField = nil
                }
                
                self?.hiddenTextField = textField
            }
        }
    }
}

// View modifier to pre-warm keyboard
struct PrewarmKeyboard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .onAppear {
                KeyboardPrewarmer.shared.prewarmKeyboard()
            }
    }
}

extension View {
    func prewarmKeyboard() -> some View {
        modifier(PrewarmKeyboard())
    }
}