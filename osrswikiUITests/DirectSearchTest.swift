//
//  DirectSearchTest.swift
//  osrswikiUITests
//
//  Direct test to click on recent search and verify highlighting
//

import XCTest

final class DirectSearchTest: XCTestCase {
    
    func testClickRecentSearchAndVerifyHighlighting() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Wait for app to load
        Thread.sleep(forTimeInterval: 3)
        
        // Take screenshot of initial state
        let initialScreenshot = XCUIScreen.main.screenshot()
        let initialAttachment = XCTAttachment(screenshot: initialScreenshot)
        initialAttachment.name = "01-initial-app-state"
        initialAttachment.lifetime = .keepAlways
        add(initialAttachment)
        
        // Look for "dragon scimitar" button in recent searches
        let dragonScimitarButton = app.buttons["dragon scimitar"]
        if dragonScimitarButton.exists {
            print("✅ Found dragon scimitar recent search button")
            dragonScimitarButton.tap()
            
            // Wait for search results
            Thread.sleep(forTimeInterval: 5)
            
            let searchResultsScreenshot = XCUIScreen.main.screenshot()
            let searchResultsAttachment = XCTAttachment(screenshot: searchResultsScreenshot)
            searchResultsAttachment.name = "02-dragon-scimitar-search-results"
            searchResultsAttachment.lifetime = .keepAlways
            add(searchResultsAttachment)
            
            print("✅ Clicked dragon scimitar, captured search results")
        } else {
            print("❌ Could not find dragon scimitar recent search button")
            
            // Try searching manually in the text field
            let searchField = app.textFields.firstMatch
            if searchField.exists {
                searchField.tap()
                Thread.sleep(forTimeInterval: 1)
                searchField.typeText("dragon scimitar")
                Thread.sleep(forTimeInterval: 1)
                searchField.typeText("\n")
                Thread.sleep(forTimeInterval: 5)
                
                let manualSearchScreenshot = XCUIScreen.main.screenshot()
                let manualSearchAttachment = XCTAttachment(screenshot: manualSearchScreenshot)
                manualSearchAttachment.name = "03-manual-dragon-scimitar-search"
                manualSearchAttachment.lifetime = .keepAlways
                add(manualSearchAttachment)
                
                print("✅ Manual search completed")
            }
        }
        
        // Also try searching for other terms that might have highlighting
        let searchField = app.textFields.firstMatch
        if searchField.exists {
            // Clear and search for "abyssal whip" 
            searchField.tap()
            Thread.sleep(forTimeInterval: 1)
            searchField.clearAndEnterText("abyssal whip")
            searchField.typeText("\n")
            Thread.sleep(forTimeInterval: 5)
            
            let abyssalWhipScreenshot = XCUIScreen.main.screenshot()
            let abyssalWhipAttachment = XCTAttachment(screenshot: abyssalWhipScreenshot)
            abyssalWhipAttachment.name = "04-abyssal-whip-search-results"
            abyssalWhipAttachment.lifetime = .keepAlways
            add(abyssalWhipAttachment)
        }
        
        print("✅ Direct search test completed - check all screenshots for orange highlighting")
    }
}

