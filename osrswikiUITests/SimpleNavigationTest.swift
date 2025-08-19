import XCTest

final class SimpleNavigationTest: XCTestCase {
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }
    
    func testNavigateToSearchAndTakeScreenshot() throws {
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
        sleep(3)
        
        // Take initial screenshot
        let initialScreenshot = XCUIScreen.main.screenshot()
        let initialAttachment = XCTAttachment(screenshot: initialScreenshot)
        initialAttachment.name = "initial_app_state"
        initialAttachment.lifetime = .keepAlways
        add(initialAttachment)
        
        // Try to find and tap search elements using different queries
        print("Looking for search elements...")
        
        // Try tapping search tab using different selectors
        let searchTab = app.buttons["Search"]
        if searchTab.exists {
            searchTab.tap()
            sleep(2)
            print("Search tab found and tapped")
        } else {
            // Try alternative search tab selectors
            let altSearchTab = app.tabBars.buttons.element(boundBy: 2) // Third tab (0-indexed)
            if altSearchTab.exists {
                altSearchTab.tap()
                sleep(2)
                print("Alternative search tab tapped")
            }
        }
        
        // Take screenshot after navigation attempt
        let navScreenshot = XCUIScreen.main.screenshot()
        let navAttachment = XCTAttachment(screenshot: navScreenshot)
        navAttachment.name = "after_navigation_attempt"
        navAttachment.lifetime = .keepAlways
        add(navAttachment)
        
        // Try to find search field
        let searchField = app.searchFields.firstMatch
        if searchField.exists {
            searchField.tap()
            searchField.typeText("Dragon scimitar")
            sleep(2)
            
            // Look for search results
            let searchResults = app.tables.firstMatch
            if searchResults.exists && searchResults.cells.count > 0 {
                searchResults.cells.firstMatch.tap()
                sleep(3)
                
                // Take final screenshot of article page
                let articleScreenshot = XCUIScreen.main.screenshot()
                let articleAttachment = XCTAttachment(screenshot: articleScreenshot)
                articleAttachment.name = "article_page_with_bottom_bar"
                articleAttachment.lifetime = .keepAlways
                add(articleAttachment)
                
                print("Successfully navigated to article")
            }
        }
        
        // Final screenshot regardless of success
        let finalScreenshot = XCUIScreen.main.screenshot()
        let finalAttachment = XCTAttachment(screenshot: finalScreenshot)
        finalAttachment.name = "final_state"
        finalAttachment.lifetime = .keepAlways
        add(finalAttachment)
    }
}
