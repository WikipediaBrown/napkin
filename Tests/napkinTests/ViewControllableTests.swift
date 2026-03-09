//
//  Copyright (c) 2017. Uber Technologies
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import XCTest
import UIKit
@testable import napkin

@MainActor
final class ViewControllableTests: XCTestCase {

    // MARK: - Default Implementation Tests

    func testViewControllable_defaultImplementation_returnsSelf() {
        let viewController = TestViewController()

        XCTAssertTrue(viewController.uiviewController === viewController)
    }

    func testViewControllable_UIViewController_conformsToViewControllable() {
        let viewController = TestViewController()

        XCTAssertTrue(viewController is ViewControllable)
    }

    // MARK: - UIHostingController Pattern Tests

    func testViewControllable_hostingControllerPattern_returnsController() {
        let hostingController = MockHostingController()

        XCTAssertTrue(hostingController.uiviewController === hostingController)
    }

    // MARK: - Protocol Requirement Tests

    func testViewControllable_protocolRequiresUIViewController() {
        let viewController = TestViewController()
        let controllable: ViewControllable = viewController

        XCTAssertNotNil(controllable.uiviewController)
    }
}

// MARK: - Test Doubles

@MainActor
private class TestViewController: UIViewController, ViewControllable {}

@MainActor
private class MockHostingController: UIViewController, ViewControllable {
    // Simulates UIHostingController pattern where the controller itself is ViewControllable
}
