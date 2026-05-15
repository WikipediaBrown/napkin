//
//  RibHouseUITests.swift
//  napkin example UI tests — Napkin's Rib House
//
//  Drives the example app via XCUITest. The app has two child napkins
//  managed by the LaunchNapkin: a LoggedOut screen with a Login button,
//  and a LoggedIn screen showing the user's name + barbecue foods and
//  a Logout button. The LaunchNapkin holds the AuthService and swaps
//  children on login / logout.
//

import XCTest

final class RibHouseUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    func testLaunchStartsLoggedOut() {
        let title = app.staticTexts[NapkinAccessibility.LoggedOut.title]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons[NapkinAccessibility.LoggedOut.loginButton].exists)
    }

    func testLoginRevealsBarbecueFoodsAndLogoutReturns() {
        app.buttons[NapkinAccessibility.LoggedOut.loginButton].tap()

        // After login (the mock service sleeps ~200ms) we expect the
        // logged-in screen with the user's name.
        let nameLabel = app.staticTexts[NapkinAccessibility.LoggedIn.nameLabel]
        XCTAssertTrue(nameLabel.waitForExistence(timeout: 5))
        XCTAssertEqual(nameLabel.label, "Smokey Joe")

        // Barbecue list items render with identifiers like "loggedIn.food.Brisket".
        // We don't pin the exact set in the test — just confirm at least one
        // known food is visible (so the list rendered from the User object).
        XCTAssertTrue(
            app.staticTexts["\(NapkinAccessibility.LoggedIn.foodPrefix).Brisket"]
                .waitForExistence(timeout: 2)
        )

        // Logout takes us back to the logged-out screen.
        app.buttons[NapkinAccessibility.LoggedIn.logoutButton].tap()
        XCTAssertTrue(
            app.staticTexts[NapkinAccessibility.LoggedOut.title]
                .waitForExistence(timeout: 5)
        )
    }
}
