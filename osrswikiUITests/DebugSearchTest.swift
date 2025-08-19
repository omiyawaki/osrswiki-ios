//
//  DebugSearchTest.swift
//  osrswikiUITests
//
//  Simple test to click dragon scimitar and capture debug logs
//

import XCTest

final class DebugSearchTest: XCTestCase {
    
    func testDragonScimitarDebug() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Wait for app to load
        Thread.sleep(forTimeInterval: 3)
        
        // Look for "dragon scimitar" button and tap it
        let dragonScimitarButton = app.buttons["dragon scimitar"]
        if dragonScimitarButton.exists {
            print("✅ Found dragon scimitar button - tapping it")
            dragonScimitarButton.tap()
            
            // Wait longer for search results and debug logs
            print("⏳ Waiting for search results and debug logs...")
            Thread.sleep(forTimeInterval: 8)
            
            print("✅ Debug search completed - check console logs for snippet data")
        } else {
            print("❌ Could not find dragon scimitar button")
            XCTFail("Dragon scimitar button not found")
        }
    }
}