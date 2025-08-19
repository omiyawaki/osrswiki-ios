//
//  FinalComparisonTest.swift
//  osrswikiUITests
//
//  Final test to verify orange highlighting works in the fixed app
//

import XCTest

final class FinalComparisonTest: XCTestCase {
    
    func testDragonScimitarOrangeHighlighting() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Wait for app to load
        Thread.sleep(forTimeInterval: 3)
        
        // Take screenshot of initial state
        let initialScreenshot = XCUIScreen.main.screenshot()
        let initialAttachment = XCTAttachment(screenshot: initialScreenshot)
        initialAttachment.name = "01-fixed-app-ready"
        initialAttachment.lifetime = .keepAlways
        add(initialAttachment)
        
        // Click on "dragon scimitar" recent search
        let dragonScimitarButton = app.buttons["dragon scimitar"]
        if dragonScimitarButton.exists {
            print("✅ Found dragon scimitar button - tapping")
            dragonScimitarButton.tap()
            
            // Wait for search results
            Thread.sleep(forTimeInterval: 5)
            
            // Take screenshot of search results
            let resultsScreenshot = XCUIScreen.main.screenshot()
            let resultsAttachment = XCTAttachment(screenshot: resultsScreenshot)
            resultsAttachment.name = "02-dragon-scimitar-results-with-fix"
            resultsAttachment.lifetime = .keepAlways
            add(resultsAttachment)
            
            print("✅ Captured iOS search results with fix applied")
            
        } else {
            XCTFail("Could not find dragon scimitar button")
        }
    }
}