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
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif
@testable import napkin

@MainActor
final class ViewControllableTests: XCTestCase {

    // MARK: - Default Implementation Tests

    func testViewControllable_defaultImplementation_returnsSelf() {
        let viewController = TestViewController()

        #if canImport(UIKit)
        XCTAssertTrue(viewController.uiviewController === viewController)
        #elseif canImport(AppKit)
        XCTAssertTrue(viewController.nsviewController === viewController)
        #endif
    }

    func testViewControllable_UIViewController_conformsToViewControllable() {
        let viewController = TestViewController()

        XCTAssertTrue(viewController is ViewControllable)
    }

    // MARK: - HostingController Pattern Tests

    func testViewControllable_hostingControllerPattern_returnsController() {
        let hostingController = MockHostingController()

        #if canImport(UIKit)
        XCTAssertTrue(hostingController.uiviewController === hostingController)
        #elseif canImport(AppKit)
        XCTAssertTrue(hostingController.nsviewController === hostingController)
        #endif
    }

    // MARK: - Protocol Requirement Tests

    func testViewControllable_protocolRequiresViewController() {
        let viewController = TestViewController()
        let controllable: ViewControllable = viewController

        #if canImport(UIKit)
        XCTAssertNotNil(controllable.uiviewController)
        #elseif canImport(AppKit)
        XCTAssertNotNil(controllable.nsviewController)
        #endif
    }
}

// MARK: - Test Doubles

#if canImport(UIKit)
@MainActor
private class TestViewController: UIViewController, ViewControllable {}

@MainActor
private class MockHostingController: UIViewController, ViewControllable {}
#elseif canImport(AppKit)
@MainActor
private class TestViewController: NSViewController, ViewControllable {
    override func loadView() { self.view = NSView() }
}

@MainActor
private class MockHostingController: NSViewController, ViewControllable {
    override func loadView() { self.view = NSView() }
}
#endif
