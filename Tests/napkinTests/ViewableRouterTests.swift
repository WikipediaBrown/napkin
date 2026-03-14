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
final class ViewableRouterTests: XCTestCase {

    // MARK: - Initialization Tests

    func testViewableRouter_initialization_storesInteractor() {
        let interactor = TestInteractor()
        let viewController = TestViewController()
        let router = TestViewableRouter(interactor: interactor, viewController: viewController)

        XCTAssertTrue(router.interactable === interactor)
    }

    func testViewableRouter_initialization_storesViewController() {
        let interactor = TestInteractor()
        let viewController = TestViewController()
        let router = TestViewableRouter(interactor: interactor, viewController: viewController)

        XCTAssertTrue(router.viewController === viewController)
    }

    func testViewableRouter_initialization_providesViewControllable() {
        let interactor = TestInteractor()
        let viewController = TestViewController()
        let router = TestViewableRouter(interactor: interactor, viewController: viewController)

        #if canImport(UIKit)
        XCTAssertTrue(router.viewControllable.uiviewController === viewController)
        #elseif canImport(AppKit)
        XCTAssertTrue(router.viewControllable.nsviewController === viewController)
        #endif
    }

    // MARK: - Lifecycle Tests

    func testViewableRouter_load_activatesInteractor() {
        let interactor = TestInteractor()
        let viewController = TestViewController()
        let router = TestViewableRouter(interactor: interactor, viewController: viewController)

        interactor.activate()
        router.load()

        XCTAssertTrue(interactor.isActive)
        XCTAssertTrue(router.didLoadCalled)
    }

    func testViewableRouter_load_callsDidLoad() {
        let interactor = TestInteractor()
        let viewController = TestViewController()
        let router = TestViewableRouter(interactor: interactor, viewController: viewController)

        interactor.activate()
        router.load()

        XCTAssertTrue(router.didLoadCalled)
    }

    // MARK: - Child Router Tests

    func testViewableRouter_attachChild_addsToChildren() {
        let interactor = TestInteractor()
        let viewController = TestViewController()
        let router = TestViewableRouter(interactor: interactor, viewController: viewController)

        let childInteractor = TestInteractor()
        let childViewController = TestViewController()
        let childRouter = TestViewableRouter(interactor: childInteractor, viewController: childViewController)

        router.attachChild(childRouter)

        XCTAssertEqual(router.children.count, 1)
        XCTAssertTrue(router.children.first === childRouter)
    }

    func testViewableRouter_detachChild_removesFromChildren() {
        let interactor = TestInteractor()
        let viewController = TestViewController()
        let router = TestViewableRouter(interactor: interactor, viewController: viewController)

        let childInteractor = TestInteractor()
        let childViewController = TestViewController()
        let childRouter = TestViewableRouter(interactor: childInteractor, viewController: childViewController)

        router.attachChild(childRouter)
        router.detachChild(childRouter)

        XCTAssertEqual(router.children.count, 0)
    }

    // MARK: - ViewableRouting Protocol Tests

    func testViewableRouter_conformsToViewableRouting() {
        let interactor = TestInteractor()
        let viewController = TestViewController()
        let router = TestViewableRouter(interactor: interactor, viewController: viewController)

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
private class TestViewableRouter: ViewableRouter<TestInteractor, TestViewController> {
    var didLoadCalled = false

    override func didLoad() {
        super.didLoad()
        didLoadCalled = true
    }
}
