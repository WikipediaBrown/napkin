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
@testable import napkin

@MainActor
final class PresenterTests: XCTestCase {

    // MARK: - Initialization Tests

    func testPresenter_initialization_storesViewController() {
        let viewController = TestViewController()
        let presenter = TestPresenter(viewController: viewController)

        XCTAssertTrue(presenter.viewController === viewController)
    }

    func testPresenter_initialization_viewControllerIsStronglyRetained() {
        var viewController: TestViewController? = TestViewController()
        weak var weakViewController = viewController
        let presenter = TestPresenter(viewController: viewController!)

        viewController = nil

        XCTAssertNotNil(weakViewController)
        XCTAssertTrue(presenter.viewController === weakViewController)
    }

    // MARK: - ViewController Access Tests

    func testPresenter_canAccessViewControllerMethods() {
        let viewController = TestViewController()
        let presenter = TestPresenter(viewController: viewController)

        presenter.updateView()

        XCTAssertTrue(viewController.displayCalled)
    }

    func testPresenter_canPassDataToViewController() {
        let viewController = TestViewController()
        let presenter = TestPresenter(viewController: viewController)

        presenter.presentData("Test Data")

        XCTAssertEqual(viewController.lastDisplayedData, "Test Data")
    }

    // MARK: - Presentable Protocol Tests

    func testPresenter_conformsToPresentable() {
        let viewController = TestViewController()
        let presenter = TestPresenter(viewController: viewController)

        XCTAssertTrue(presenter is Presentable)
    }
}

// MARK: - Test Doubles

@MainActor
private protocol TestViewControllable: AnyObject {
    func display()
    func displayData(_ data: String)
}

@MainActor
private class TestViewController: TestViewControllable {
    var displayCalled = false
    var lastDisplayedData: String?

    func display() {
        displayCalled = true
    }

    func displayData(_ data: String) {
        lastDisplayedData = data
    }
}

@MainActor
private class TestPresenter: Presenter<TestViewControllable> {

    func updateView() {
        viewController.display()
    }

    func presentData(_ data: String) {
        viewController.displayData(data)
    }
}
