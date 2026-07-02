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

        let nameLabel = app.staticTexts[NapkinAccessibility.LoggedIn.nameLabel]
        XCTAssertTrue(nameLabel.waitForExistence(timeout: 5))
        XCTAssertEqual(nameLabel.label, "Smokey Joe")

        XCTAssertTrue(
            app.staticTexts["\(NapkinAccessibility.LoggedIn.foodPrefix).Brisket"]
                .waitForExistence(timeout: 2)
        )

        // The live pit summary renders from the seeded board.
        XCTAssertTrue(
            app.staticTexts[NapkinAccessibility.LoggedIn.pitSummary]
                .waitForExistence(timeout: 5)
        )

        // Push the pit board; the seeded brisket is on it (fan-out
        // subscriber #2 sees the same board as the header).
        app.buttons[NapkinAccessibility.LoggedIn.pitBoardButton].tap()
        XCTAssertTrue(
            app.staticTexts["\(NapkinAccessibility.PitBoard.itemPrefix).brisket"]
                .waitForExistence(timeout: 5)
        )

        // Back pops the board; didMove(toParent: nil) detaches the child.
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(nameLabel.waitForExistence(timeout: 5))

        // Re-push proves the logical tree was detached cleanly.
        app.buttons[NapkinAccessibility.LoggedIn.pitBoardButton].tap()
        XCTAssertTrue(
            app.staticTexts["\(NapkinAccessibility.PitBoard.itemPrefix).brisket"]
                .waitForExistence(timeout: 5)
        )
        app.navigationBars.buttons.firstMatch.tap()

        // Logout takes us back to the logged-out screen.
        app.buttons[NapkinAccessibility.LoggedIn.logoutButton].tap()
        XCTAssertTrue(
            app.staticTexts[NapkinAccessibility.LoggedOut.title]
                .waitForExistence(timeout: 5)
        )
    }

    func testPitSummaryChangesUnderFastTicks() {
        app.terminate()
        app.launchArguments += ["-fastTicks"]
        app.launch()

        app.buttons[NapkinAccessibility.LoggedOut.loginButton].tap()
        // The pitSummary identifier sits on a container HStack whose three
        // Texts aren't accessibility-combined, so the identifier propagates
        // to all three static texts (in view order: "LIVE FROM THE PIT",
        // "·", then the live summary). boundBy: 2 pins the third — the one
        // whose label actually changes — so `.label` resolves to a single
        // element instead of throwing on the ambiguous match.
        let summary = app.staticTexts.matching(identifier: NapkinAccessibility.LoggedIn.pitSummary).element(boundBy: 2)
        XCTAssertTrue(summary.waitForExistence(timeout: 5))
        let initial = summary.label

        // Under -fastTicks (0.5s) the board advances quickly; wait for the
        // summary to change at least once. Never assert a specific later
        // state — only that it moved.
        let changed = expectation(description: "pit summary changed")
        Task { @MainActor in
            for _ in 0..<40 {
                if summary.exists, summary.label != initial {
                    changed.fulfill()
                    return
                }
                try? await Task.sleep(for: .milliseconds(250))
            }
        }
        wait(for: [changed], timeout: 15)
    }
}
