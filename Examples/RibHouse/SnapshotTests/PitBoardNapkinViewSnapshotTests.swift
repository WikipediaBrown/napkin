//
//  PitBoardNapkinViewSnapshotTests.swift
//  RibHouse snapshot tests
//
//  Pins the PitBoard's appearance for a fixed board state: grouped stage
//  sections, amber stage tags, and the specials list.
//

import SnapshotTesting
import SwiftUI
import XCTest
@testable import RibHouse

@MainActor
final class PitBoardNapkinViewSnapshotTests: XCTestCase {

    func testPitBoardNapkinView() {
        let viewController = PitBoardNapkinViewController()
        let presenter = PitBoardNapkinPresenter(viewController: viewController)
        presenter.sections = [
            PitBoardSection(id: 0, title: "Lighting", items: [
                PitItem(id: "ribs", name: "St. Louis Ribs", stage: .lighting),
                PitItem(id: "sausage", name: "Smoked Sausage", stage: .lighting),
            ]),
            PitBoardSection(id: 1, title: "Smoking", items: [
                PitItem(id: "brisket", name: "Brisket", stage: .smoking),
                PitItem(id: "pulled-pork", name: "Pulled Pork", stage: .smoking),
            ]),
            PitBoardSection(id: 2, title: "Resting", items: [
                PitItem(id: "burnt-ends", name: "Burnt Ends", stage: .resting),
            ]),
        ]
        presenter.specials = [
            Special(id: "hot-links", name: "Hot Links"),
            Special(id: "beef-rib", name: "Dino Beef Rib"),
        ]
        viewController.bind(presenter: presenter)
        assertSnapshot(of: viewController, as: .image(on: .iPhone13Pro))
    }
}
