//
//  SwiftBiomesUITests.swift
//  SwiftBiomesUITests
//
//  Created by Christopher Lloyd on 2026.07.05.
//

import XCTest

final class SwiftBiomesUITests: XCTestCase {

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
        // XCUIAutomation Documentation
        // https://developer.apple.com/documentation/xcuiautomation
    }

    @MainActor
    func testSeedFinderCoreFlow() throws {
        let app = XCUIApplication()
        app.launch()

        let findSeedsButton = app.buttons["Find Seeds"].firstMatch
        XCTAssertTrue(findSeedsButton.waitForExistence(timeout: 10))
        findSeedsButton.click()

        let sheet = app.sheets.firstMatch
        if !sheet.waitForExistence(timeout: 5) {
            findSeedsButton.click()
        }
        XCTAssertTrue(sheet.waitForExistence(timeout: 10))

        replaceText(in: sheet.textFields["seedFinder.startSeed"], with: "260")
        replaceText(in: sheet.textFields["seedFinder.endSeed"], with: "264")

        let searchButton = sheet.buttons["seedFinder.search"]
        XCTAssertTrue(searchButton.isEnabled)
        searchButton.click()

        let result = sheet.staticTexts["262"].firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 10))
        result.click()

        let useSeedButton = sheet.buttons["seedFinder.useSeed"]
        XCTAssertTrue(useSeedButton.isEnabled)

        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "Seed Finder Result"
        attachment.lifetime = .keepAlways
        add(attachment)

        useSeedButton.click()
        XCTAssertTrue(sheet.waitForNonExistence(timeout: 5))
        XCTAssertEqual(app.textFields["world.seed"].value as? String, "262")
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }

    @MainActor
    private func replaceText(in field: XCUIElement, with value: String) {
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.click()
        field.typeKey("a", modifierFlags: .command)
        field.typeText(value)
    }
}
