//
//  LoggedInNapkinViewSnapshotTests.swift
//  RibHouse snapshot tests
//
//  Pins the LoggedIn napkin's appearance for a known User: dark green
//  background, italic "Smokey Joe" wordmark, mono-caps subtitle, and the
//  spec-list of barbecue foods (01 · Brisket, 02 · Pulled Pork, ...).
//

import SnapshotTesting
import SwiftUI
import XCTest
@testable import RibHouse

@MainActor
final class LoggedInNapkinViewSnapshotTests: XCTestCase {

    private let smokeyJoe = User(
        name: "Smokey Joe",
        barbecueFoods: [
            "Brisket",
            "Pulled Pork",
            "St. Louis Ribs",
            "Burnt Ends",
            "Smoked Sausage",
        ]
    )

    func testLoggedInNapkinView() {
        let view = LoggedInNapkinView(user: smokeyJoe, pitSummary: "2 SMOKING · 1 RESTING")
        let vc = UIHostingController(rootView: view)
        assertSnapshot(of: vc, as: .image(on: .iPhone13Pro))
    }
}
