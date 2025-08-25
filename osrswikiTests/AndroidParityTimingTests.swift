//
//  AndroidParityTimingTests.swift
//  osrswikiTests
//
//  Test for Android parity progress timing - verifying JavaScript content readiness
//

import XCTest
import SwiftUI
@testable import osrswiki

final class AndroidParityTimingTests: XCTestCase {
    
    @MainActor 
    func testAndroidParityProgressCompletion() throws {
        print("\n🚀 ANDROID PARITY TEST: Verifying JavaScript-based progress completion")
        
        let expectation = XCTestExpectation(description: "Android parity progress completion")
        
        let viewModel = ArticleViewModel(
            pageUrl: URL(string: "https://oldschool.runescape.wiki/w/Abyssal_whip")!,
            pageTitle: "Abyssal whip"
        )
        
        var webKitCompletionTime: Date?
        var javaScriptCompletionTime: Date?
        
        // Monitor progress changes to track different completion events
        let progressCancellable = viewModel.$loadingProgress.sink { progress in
            print("📊 Progress Update: \(String(format: "%.1f", progress * 100))%")
            
            if progress >= 0.95 && progress < 1.0 && webKitCompletionTime == nil {
                webKitCompletionTime = Date()
                print("📊 ANDROID PARITY: WebKit completed (95%), waiting for JavaScript...")
            }
        }
        
        // Monitor loading state changes for final completion
        let loadingCancellable = viewModel.$isLoading.sink { isLoading in
            if !isLoading && javaScriptCompletionTime == nil && webKitCompletionTime != nil {
                javaScriptCompletionTime = Date()
                print("📊 ANDROID PARITY: JavaScript completion detected!")
                expectation.fulfill()
            }
        }
        
        DispatchQueue.main.async {
            viewModel.loadArticle(theme: osrsLightTheme())
        }
        
        wait(for: [expectation], timeout: 30.0)
        
        progressCancellable.cancel()
        loadingCancellable.cancel()
        
        // Verify Android parity behavior
        if let webKitTime = webKitCompletionTime,
           let jsTime = javaScriptCompletionTime {
            let webKitToJsDelay = jsTime.timeIntervalSince(webKitTime)
            print("📊 ANDROID PARITY ANALYSIS:")
            print("   - WebKit completion (95%): \(webKitTime)")
            print("   - JavaScript completion (100%): \(jsTime)")
            print("   - Delay between WebKit and JS: \(String(format: "%.3f", webKitToJsDelay))s")
            
            // This delay should be measurable (>0) proving we wait for JavaScript
            XCTAssertGreaterThan(webKitToJsDelay, 0.0, 
                               "Should wait for JavaScript after WebKit completes")
            
            // But delay shouldn't be excessive (Android target: reasonable content readiness time)
            XCTAssertLessThan(webKitToJsDelay, 5.0, 
                            "JavaScript content readiness shouldn't take too long")
            
            print("✅ ANDROID PARITY VERIFIED: Progress waits for JavaScript content readiness")
        } else {
            XCTFail("Failed to capture both WebKit and JavaScript completion times")
        }
    }
    
    @MainActor 
    func testProgressStaysAt95UntilJavaScript() throws {
        print("\n🧪 ANDROID PARITY: Testing progress caps at 95% until JavaScript ready")
        
        let expectation = XCTestExpectation(description: "Progress behavior verification")
        
        let viewModel = ArticleViewModel(
            pageUrl: URL(string: "https://oldschool.runescape.wiki/w/Abyssal_whip")!,
            pageTitle: "Abyssal whip"
        )
        
        var maxProgressBeforeCompletion: Double = 0.0
        var finalProgress: Double = 0.0
        
        let progressCancellable = viewModel.$loadingProgress.sink { progress in
            if viewModel.isLoading {
                maxProgressBeforeCompletion = max(maxProgressBeforeCompletion, progress)
            } else {
                finalProgress = progress
                expectation.fulfill()
            }
        }
        
        DispatchQueue.main.async {
            viewModel.loadArticle(theme: osrsLightTheme())
        }
        
        wait(for: [expectation], timeout: 30.0)
        
        progressCancellable.cancel()
        
        print("📊 PROGRESS BEHAVIOR ANALYSIS:")
        print("   - Max progress while loading: \(String(format: "%.1f", maxProgressBeforeCompletion * 100))%")
        print("   - Final progress: \(String(format: "%.1f", finalProgress * 100))%")
        
        // ANDROID PARITY: Progress should cap at 95% while loading
        XCTAssertLessThanOrEqual(maxProgressBeforeCompletion, 0.95, 
                               "Progress should not exceed 95% until JavaScript completion")
        
        // Final progress should be 100%
        XCTAssertEqual(finalProgress, 1.0, accuracy: 0.01, 
                      "Final progress should be 100%")
        
        print("✅ ANDROID PARITY VERIFIED: Progress caps at 95% until content ready")
    }
}