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
final class LaunchRouterTests: XCTestCase {

    // MARK: - Initialization Tests

    func testLaunchRouter_initialization_storesInteractor() {
        let interactor = TestInteractor()
        let viewController = TestViewController()
        let router = TestLaunchRouter(interactor: interactor, viewController: viewController)

        XCTAssertTrue(router.interactable === interactor)
    }

    func testLaunchRouter_initialization_storesViewController() {
        let interactor = TestInteractor()
        let viewController = TestViewController()
        let router = TestLaunchRouter(interactor: interactor, viewController: viewController)

        XCTAssertTrue(router.viewController === viewController)
    }

    // MARK: - Launch Tests

    func testLaunchRouter_launch_setsRootViewController() {
        let interactor = TestInteractor()
        let viewController = TestViewController()
        let router = TestLaunchRouter(interactor: interactor, viewController: viewController)
        #if canImport(UIKit)
        let window = UIWindow()
        #elseif canImport(AppKit)
        let window = NSWindow()
        #endif

        router.launch(from: window)

        #if canImport(UIKit)
        XCTAssertTrue(window.rootViewController === viewController)
        #elseif canImport(AppKit)
        XCTAssertTrue(window.contentViewController === viewController)
        #endif
    }

    func testLaunchRouter_launch_activatesInteractor() {
        let interactor = TestInteractor()
        let viewController = TestViewController()
        let router = TestLaunchRouter(interactor: interactor, viewController: viewController)
        #if canImport(UIKit)
        let window = UIWindow()
        #elseif canImport(AppKit)
        let window = NSWindow()
        #endif

        router.launch(from: window)

        XCTAssertTrue(interactor.isActive)
    }

    func testLaunchRouter_launch_callsDidLoad() {
        let interactor = TestInteractor()
        let viewController = TestViewController()
        let router = TestLaunchRouter(interactor: interactor, viewController: viewController)
        #if canImport(UIKit)
        let window = UIWindow()
        #elseif canImport(AppKit)
        let window = NSWindow()
        #endif

        router.launch(from: window)

        XCTAssertTrue(router.didLoadCalled)
    }

    // MARK: - LaunchRouting Protocol Tests

    func testLaunchRouter_conformsToLaunchRouting() {
        let interactor = TestInteractor()
        let viewController = TestViewController()
        let router = TestLaunchRouter(interactor: interactor, viewController: viewController)

        XCTAssertTrue((router as Any) is LaunchRouting)
    }

    func testLaunchRouter_conformsToViewableRouting() {
        let interactor = TestInteractor()
        let viewController = TestViewController()
        let router = TestLaunchRouter(interactor: interactor, viewController: viewController)

        XCTAssertTrue((router as Any) is ViewableRouting)
    }
}

// MARK: - Test Doubles

@MainActor
private class TestInteractor: Interactor {}

#if canImport(UIKit)
@MainActor
private class TestViewController: UIViewController, ViewControllable {}
#elseif canImport(AppKit)
@MainActor
private class TestViewController: NSViewController, ViewControllable {
    override func loadView() { self.view = NSView() }
}
#endif

@MainActor
private class TestLaunchRouter: LaunchRouter<TestInteractor, TestViewController> {
    var didLoadCalled = false

    override func didLoad() {
        super.didLoad()
        didLoadCalled = true
    }
}
