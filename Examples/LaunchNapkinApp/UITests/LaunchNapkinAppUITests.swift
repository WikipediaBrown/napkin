//
//  LaunchNapkinAppUITests.swift
//  napkin example UI tests
//
//  Demonstrates how to drive the napkin example app via XCUITest using the
//  identifiers defined in AccessibilityIdentifiers.swift. Mirrors how a real
//  consumer would write end-to-end tests against an app built with napkin.
//

import XCTest

final class LaunchNapkinAppUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    func testLaunchScreenShowsBothNapkinEntryButtons() {
        let greeting = app.staticTexts[NapkinAccessibility.Launch.greeting]
        XCTAssertTrue(greeting.waitForExistence(timeout: 5))
        XCTAssertEqual(greeting.label, "Hello, World!")

        XCTAssertTrue(app.buttons[NapkinAccessibility.Launch.showCounterButton].exists)
        XCTAssertTrue(app.buttons[NapkinAccessibility.Launch.showQuoteButton].exists)
    }

    func testCounterIncrementsAndDecrements() {
        app.buttons[NapkinAccessibility.Launch.showCounterButton].tap()

        let count = app.staticTexts[NapkinAccessibility.Counter.countLabel]
        XCTAssertTrue(count.waitForExistence(timeout: 5))
        XCTAssertEqual(count.label, "0")

        app.buttons[NapkinAccessibility.Counter.incrementButton].tap()
        app.buttons[NapkinAccessibility.Counter.incrementButton].tap()
        XCTAssertEqual(count.label, "2")

        app.buttons[NapkinAccessibility.Counter.decrementButton].tap()
        XCTAssertEqual(count.label, "1")

        app.buttons[NapkinAccessibility.Counter.doneButton].tap()
        // Back at the launch screen
        XCTAssertTrue(
            app.buttons[NapkinAccessibility.Launch.showCounterButton]
                .waitForExistence(timeout: 5)
        )
    }

    func testQuoteRerollsAndDismisses() {
        app.buttons[NapkinAccessibility.Launch.showQuoteButton].tap()

        let quote = app.staticTexts[NapkinAccessibility.Quote.quoteLabel]
        XCTAssertTrue(quote.waitForExistence(timeout: 5))
        let initialQuote = quote.label
        XCTAssertFalse(initialQuote.isEmpty)

        // Reroll a few times — at least one of the new values should differ from
        // the initial value (the quotes array has more than one entry).
        var sawDifferent = false
        for _ in 0..<10 {
            app.buttons[NapkinAccessibility.Quote.newQuoteButton].tap()
            if quote.label != initialQuote {
                sawDifferent = true
                break
            }
        }
        XCTAssertTrue(sawDifferent, "New Quote button should produce a different quote within 10 taps")

        app.buttons[NapkinAccessibility.Quote.doneButton].tap()
        XCTAssertTrue(
            app.buttons[NapkinAccessibility.Launch.showQuoteButton]
                .waitForExistence(timeout: 5)
        )
    }
}
