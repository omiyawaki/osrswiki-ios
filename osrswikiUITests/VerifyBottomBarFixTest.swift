import XCTest

final class VerifyBottomBarFixTest: XCTestCase {
    
    override func setUpWithError() throws {
        continueAfterFailure = false
    }
    
    func testBottomBarFixInArticleView() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Wait for search screen to load
        let searchTitle = app.staticTexts["Search"]
        XCTAssertTrue(searchTitle.waitForExistence(timeout: 10))
        
        // Verify main tab bar is visible on search screen
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.exists)
        let searchTabButton = app.tabBars.buttons["Search"]
        XCTAssertTrue(searchTabButton.exists)
        
        // Look for the Varrock search result
        let varrockElement = app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'Varrock'")).firstMatch
        if varrockElement.exists {
            // Tap on Varrock search result
            varrockElement.tap()
            print("Tapped on Varrock search result")
        } else {
            // Alternative: tap on any available search result
            let searchResults = app.tables.firstMatch
            if searchResults.exists {
                let firstResult = searchResults.cells.firstMatch
                if firstResult.exists {
                    firstResult.tap()
                    print("Tapped on first available search result")
                }
            }
        }
        
        // Wait for article to load
        sleep(3)
        
        // Check if we're now in an article view
        // We should verify that the main tab bar is hidden and only article toolbar is visible
        
        // The fix should hide the main tab bar when viewing articles
        let mainTabBar = app.tabBars.buttons["Search"]
        let isMainTabBarHidden = !mainTabBar.exists || !mainTabBar.isHittable
        
        print("Main tab bar hidden: \(isMainTabBarHidden)")
        
        // Check for article-specific elements (these might vary based on the article)
        // We'll look for common article elements
        let articleToolbar = app.toolbars.firstMatch
        let hasArticleToolbar = articleToolbar.exists
        
        print("Article toolbar present: \(hasArticleToolbar)")
        
        // Wait a bit more to ensure everything is loaded
        sleep(2)
        
        // Final assertion: Main tab bar should be hidden in article view
        XCTAssertTrue(isMainTabBarHidden, "Main tab bar should be hidden when viewing an article")
        
        print("Test completed - verifying bottom bar fix")
    }
}
