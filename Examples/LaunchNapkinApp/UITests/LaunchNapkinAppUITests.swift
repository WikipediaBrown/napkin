//
//  LaunchNapkinAppUITests.swift
//  napkin example UI tests
//
//  Drives the napkin example app via XCUITest using the identifiers defined
//  in AccessibilityIdentifiers.swift. The example app has two child napkins
//  (Ping, Pong) that are swapped in and out of the LaunchNapkin container
//  one at a time via a single "Swap" button on each child.
//

import XCTest

final class LaunchNapkinAppUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    func testLaunchStartsOnPing() {
        let pingLabel = app.staticTexts[NapkinAccessibility.Ping.label]
        XCTAssertTrue(pingLabel.waitForExistence(timeout: 5))
        XCTAssertEqual(pingLabel.label, "Ping")
        XCTAssertTrue(app.buttons[NapkinAccessibility.Ping.swapButton].exists)
    }

    func testSwapAlternatesPingAndPong() {
        // Initial state: Ping
        let pingLabel = app.staticTexts[NapkinAccessibility.Ping.label]
        XCTAssertTrue(pingLabel.waitForExistence(timeout: 5))

        // First swap: Ping → Pong
        app.buttons[NapkinAccessibility.Ping.swapButton].tap()
        let pongLabel = app.staticTexts[NapkinAccessibility.Pong.label]
        XCTAssertTrue(pongLabel.waitForExistence(timeout: 5))
        XCTAssertEqual(pongLabel.label, "Pong")
        XCTAssertFalse(app.staticTexts[NapkinAccessibility.Ping.label].exists)

        // Second swap: Pong → Ping
        app.buttons[NapkinAccessibility.Pong.swapButton].tap()
        XCTAssertTrue(
            app.staticTexts[NapkinAccessibility.Ping.label].waitForExistence(timeout: 5)
        )
        XCTAssertFalse(app.staticTexts[NapkinAccessibility.Pong.label].exists)

        // Third swap to confirm it keeps alternating cleanly
        app.buttons[NapkinAccessibility.Ping.swapButton].tap()
        XCTAssertTrue(
            app.staticTexts[NapkinAccessibility.Pong.label].waitForExistence(timeout: 5)
        )
    }
}
