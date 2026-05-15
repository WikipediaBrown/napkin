//
//  LoggedOutNapkinViewSnapshotTests.swift
//  RibHouse snapshot tests
//
//  Pins the LoggedOut napkin's appearance: paper-cream background with
//  the editorial kicker, serif-italic "smokehouse" hero, hairline, and
//  ink LOGIN button. Reference PNG is committed under `__Snapshots__/`
//  so any visual regression flips the test red.
//

import SnapshotTesting
import SwiftUI
import XCTest
@testable import RibHouse

@MainActor
final class LoggedOutNapkinViewSnapshotTests: XCTestCase {

    func testLoggedOutNapkinView() {
        let view = LoggedOutNapkinView()
        let vc = UIHostingController(rootView: view)
        assertSnapshot(of: vc, as: .image(on: .iPhone13Pro))
    }
}
