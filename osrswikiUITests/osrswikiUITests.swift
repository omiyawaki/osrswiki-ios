//
//  OSRS_WikiUITests.swift
//  OSRS WikiUITests
//
//  Created by Osamu Miyawaki on 7/29/25.
//

import XCTest

final class osrswikiUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }
    
    @MainActor
    func testNavigateToMoreTab() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Wait for the tab bar to appear
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10))
        
        // Tap the More tab
        let moreTab = tabBar.buttons["More"]
        XCTAssertTrue(moreTab.exists)
        moreTab.tap()
        
        // Wait for the More view to appear
        let moreNavigationBar = app.navigationBars["More"]
        XCTAssertTrue(moreNavigationBar.waitForExistence(timeout: 5))
        
        // Take a screenshot
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "More Tab Screenshot"
        add(screenshot)
    }
    
    @MainActor
    func testNavigateToAppearanceSettings() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Navigate to More tab
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10))
        let moreTab = tabBar.buttons["More"]
        moreTab.tap()
        
        // Tap on Appearance settings
        let appearanceRow = app.buttons["Appearance"]
        XCTAssertTrue(appearanceRow.waitForExistence(timeout: 5))
        appearanceRow.tap()
        
        // Wait for Appearance view to load
        let appearanceNav = app.navigationBars["Appearance"]
        XCTAssertTrue(appearanceNav.waitForExistence(timeout: 5))
        
        // Take screenshot of Appearance Settings
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Appearance Settings Screenshot"
        add(screenshot)
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
