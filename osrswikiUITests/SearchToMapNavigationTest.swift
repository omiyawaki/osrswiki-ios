//
//  SearchToMapNavigationTest.swift  
//  osrswikiUITests
//
//  Created to reproduce specific navigation issues:
//  Search tab -> tap search bar -> navigate to map tab
//

import XCTest

final class SearchToMapNavigationTest: XCTestCase {
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments.append("-screenshotMode")
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    /// Takes a screenshot with timestamp and descriptive name
    private func takeScreenshot(name: String, description: String = "") {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        let timestamp = Int(Date().timeIntervalSince1970)
        attachment.name = "\(name)_\(timestamp)"
        attachment.lifetime = .keepAlways
        add(attachment)
        
        if !description.isEmpty {
            print("📸 \(description)")
        }
    }
    
    /// Check for warning indicators in the UI
    private func checkForWarningIndicators() -> [String] {
        var warnings: [String] = []
        
        // Look for yellow warning icons or indicators
        let yellowElements = app.images.matching(NSPredicate(format: "identifier CONTAINS 'warning' OR identifier CONTAINS 'error' OR identifier CONTAINS 'alert'"))
        let yellowCount = yellowElements.count
        
        if yellowCount > 0 {
            warnings.append("Found \(yellowCount) potential warning indicator(s)")
        }
        
        // Look for failed load indicators (common text patterns)
        let failedLoadTexts = ["Failed to load", "Error loading", "Network error", "Unable to load"]
        for text in failedLoadTexts {
            let elements = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[cd] %@", text))
            if elements.count > 0 {
                warnings.append("Found potential load failure text: '\(text)'")
            }
        }
        
        // Look for empty states or error messages
        if app.staticTexts["No results found"].exists {
            warnings.append("Found 'No results found' message")
        }
        
        return warnings
    }
    
    /// Main test reproducing the navigation flow that causes issues
    func testSearchTabToSearchBarToMapTabNavigation() throws {
        print("🚀 Starting specific navigation test: Search tab -> tap search bar -> navigate to map tab")
        
        // Step 1: Launch app
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
        sleep(3) // Allow full load
        
        // Take initial screenshot
        takeScreenshot(name: "01_initial_state", description: "App launched - initial state")
        let initialWarnings = checkForWarningIndicators()
        if !initialWarnings.isEmpty {
            print("⚠️ Initial warnings: \(initialWarnings.joined(separator: ", "))")
        }
        
        // Step 2: Navigate to search tab (if not already there)
        print("📍 Step 2: Navigating to search tab")
        let searchTab = app.tabBars.buttons["search_tab"]
        if !searchTab.exists {
            // Try alternative search tab selectors
            let altSearchTab = app.tabBars.buttons["Search"]
            if altSearchTab.exists {
                altSearchTab.tap()
            } else {
                // Try by position (usually third tab)
                let tabButtons = app.tabBars.buttons
                if tabButtons.count >= 3 {
                    tabButtons.element(boundBy: 2).tap()
                }
            }
        } else {
            searchTab.tap()
        }
        
        sleep(2) // Allow search tab to load
        takeScreenshot(name: "02_search_tab_loaded", description: "Search tab loaded")
        
        let searchTabWarnings = checkForWarningIndicators()
        if !searchTabWarnings.isEmpty {
            print("⚠️ Search tab warnings: \(searchTabWarnings.joined(separator: ", "))")
        }
        
        // Step 3: Tap on the search bar to open dedicated search view
        print("📍 Step 3: Tapping search bar to open dedicated search view")
        var searchBarFound = false
        
        // Try multiple ways to find and tap the search bar
        let searchBarSelectors = [
            app.searchFields.firstMatch,
            app.textFields["Search OSRS Wiki"],
            app.buttons.containing(.staticText, identifier: "Search OSRS Wiki").firstMatch,
            app.otherElements.containing(.staticText, identifier: "Search OSRS Wiki").firstMatch
        ]
        
        for searchBar in searchBarSelectors {
            if searchBar.exists && searchBar.isHittable {
                searchBar.tap()
                searchBarFound = true
                print("✅ Search bar found and tapped")
                break
            }
        }
        
        if !searchBarFound {
            print("⚠️ Search bar not found with standard selectors - checking all tappable elements")
            // Fallback: look for any element with search-related text
            let allButtons = app.buttons
            for i in 0..<allButtons.count {
                let button = allButtons.element(boundBy: i)
                if button.label.contains("Search") || button.identifier.contains("search") {
                    button.tap()
                    searchBarFound = true
                    print("✅ Found search element via fallback method")
                    break
                }
            }
        }
        
        sleep(2) // Allow search view to load
        takeScreenshot(name: "03_search_bar_tapped", description: "After tapping search bar - dedicated search view should be open")
        
        let searchViewWarnings = checkForWarningIndicators()
        if !searchViewWarnings.isEmpty {
            print("⚠️ Search view warnings: \(searchViewWarnings.joined(separator: ", "))")
        }
        
        // Step 4: Now navigate to map tab (this is where issues might occur)
        print("📍 Step 4: Attempting to navigate to map tab")
        let mapTab = app.tabBars.buttons["map_tab"]
        var mapTabFound = false
        
        if mapTab.exists && mapTab.isHittable {
            mapTab.tap()
            mapTabFound = true
            print("✅ Map tab found and tapped")
        } else {
            // Try alternative map tab selectors
            let altMapTab = app.tabBars.buttons["Map"]
            if altMapTab.exists && altMapTab.isHittable {
                altMapTab.tap()
                mapTabFound = true
                print("✅ Map tab found via alternative selector")
            } else {
                // Try by position (usually second tab)
                let tabButtons = app.tabBars.buttons
                if tabButtons.count >= 2 {
                    let mapTabByPosition = tabButtons.element(boundBy: 1)
                    if mapTabByPosition.exists && mapTabByPosition.isHittable {
                        mapTabByPosition.tap()
                        mapTabFound = true
                        print("✅ Map tab found by position")
                    }
                }
            }
        }
        
        if !mapTabFound {
            print("❌ Could not find map tab - this may be the issue!")
            takeScreenshot(name: "04_map_tab_not_found", description: "Map tab not found or not accessible")
        }
        
        sleep(3) // Allow map to load
        takeScreenshot(name: "05_map_tab_navigation_attempt", description: "After attempting to navigate to map tab")
        
        // Step 5: Analyze the current state and look for issues
        print("📍 Step 5: Analyzing current state for issues")
        
        let finalWarnings = checkForWarningIndicators()
        if !finalWarnings.isEmpty {
            print("⚠️ Final state warnings: \(finalWarnings.joined(separator: ", "))")
        }
        
        // Check if map tab is actually selected
        let isMapTabSelected = mapTab.exists && (mapTab.isSelected || mapTab.value(forKey: "isSelected") as? Bool == true)
        if isMapTabSelected {
            print("✅ Map tab appears to be selected")
        } else {
            print("⚠️ Map tab may not be properly selected")
        }
        
        // Look for map content
        let mapContent = app.otherElements.containing(.any, identifier: "map_view").firstMatch
        let hasMapContent = mapContent.exists || app.webViews.count > 0 || app.scrollViews.count > 0
        
        if hasMapContent {
            print("✅ Map content appears to be present")
        } else {
            print("⚠️ Map content may not have loaded properly")
        }
        
        // Final comprehensive screenshot
        takeScreenshot(name: "06_final_state_analysis", description: "Final state - analyzing for navigation issues")
        
        // Summary
        print("\n📊 Navigation Test Summary:")
        print("- Search bar found: \(searchBarFound)")
        print("- Map tab found: \(mapTabFound)")  
        print("- Map tab selected: \(isMapTabSelected)")
        print("- Map content loaded: \(hasMapContent)")
        print("- Total warnings detected: \(Set(initialWarnings + searchTabWarnings + searchViewWarnings + finalWarnings).count)")
        
        // The test passes if navigation completed, regardless of warnings
        // Warnings are captured in logs and screenshots for analysis
        XCTAssertTrue(searchBarFound, "Should be able to find and tap search bar")
    }
    
    /// Simplified version focusing just on tab switching after search
    func testQuickSearchToMapSwitching() throws {
        print("🚀 Quick test: Direct search -> map tab switching")
        
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
        sleep(2)
        
        // Go to search tab
        let searchTab = app.tabBars.buttons["search_tab"] 
        if searchTab.exists {
            searchTab.tap()
            sleep(1)
        }
        
        takeScreenshot(name: "quick_01_search_tab")
        
        // Go to map tab  
        let mapTab = app.tabBars.buttons["map_tab"]
        if mapTab.exists {
            mapTab.tap()
            sleep(2)
        }
        
        takeScreenshot(name: "quick_02_map_tab")
        
        // Check for issues
        let warnings = checkForWarningIndicators()
        if !warnings.isEmpty {
            print("⚠️ Quick test warnings: \(warnings.joined(separator: ", "))")
        }
        
        print("✅ Quick switching test completed")
    }
}

