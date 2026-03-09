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
import Combine
@testable import napkin

@MainActor
final class PresentableInteractorTests: XCTestCase {

    private var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        cancellables = []
    }

    override func tearDown() {
        cancellables = nil
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testPresentableInteractor_initialization_storesPresenter() {
        let presenter = TestPresenter()
        let interactor = TestPresentableInteractor(presenter: presenter)

        XCTAssertTrue(interactor.presenter === presenter)
    }

    func testPresentableInteractor_initialization_presenterIsStronglyRetained() {
        var presenter: TestPresenter? = TestPresenter()
        weak var weakPresenter = presenter
        let interactor = TestPresentableInteractor(presenter: presenter!)

        presenter = nil

        XCTAssertNotNil(weakPresenter)
        XCTAssertTrue(interactor.presenter === weakPresenter)
    }

    // MARK: - Lifecycle Tests

    func testPresentableInteractor_activate_becomesActive() {
        let presenter = TestPresenter()
        let interactor = TestPresentableInteractor(presenter: presenter)

        interactor.activate()

        XCTAssertTrue(interactor.isActive)
    }

    func testPresentableInteractor_activate_callsDidBecomeActive() {
        let presenter = TestPresenter()
        let interactor = TestPresentableInteractor(presenter: presenter)

        interactor.activate()

        XCTAssertTrue(interactor.didBecomeActiveCalled)
    }

    func testPresentableInteractor_deactivate_callsWillResignActive() {
        let presenter = TestPresenter()
        let interactor = TestPresentableInteractor(presenter: presenter)

        interactor.activate()
        interactor.deactivate()

        XCTAssertTrue(interactor.willResignActiveCalled)
    }

    // MARK: - Presenter Access Tests

    func testPresentableInteractor_canAccessPresenterMethods() {
        let presenter = TestPresenter()
        let interactor = TestPresentableInteractor(presenter: presenter)

        interactor.activate()
        interactor.callPresenterMethod()

        XCTAssertTrue(presenter.methodCalled)
    }

    func testPresentableInteractor_presenterAccessibleBeforeActivation() {
        let presenter = TestPresenter()
        let interactor = TestPresentableInteractor(presenter: presenter)

        interactor.callPresenterMethod()

        XCTAssertTrue(presenter.methodCalled)
    }

    // MARK: - isActiveStream Tests

    func testPresentableInteractor_isActiveStream_emitsCorrectValues() {
        let presenter = TestPresenter()
        let interactor = TestPresentableInteractor(presenter: presenter)
        let expectation = expectation(description: "Stream emits values")
        var receivedValues: [Bool] = []

        interactor.isActiveStream
            .sink { value in
                receivedValues.append(value)
                if receivedValues.count == 3 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        interactor.activate()
        interactor.deactivate()

        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedValues, [false, true, false])
    }
}

// MARK: - Test Doubles

@MainActor
private protocol TestPresentable: AnyObject {
    func doSomething()
}

@MainActor
private class TestPresenter: TestPresentable {
    var methodCalled = false

    func doSomething() {
        methodCalled = true
    }
}

@MainActor
private class TestPresentableInteractor: PresentableInteractor<TestPresentable> {
    var didBecomeActiveCalled = false
    var willResignActiveCalled = false

    override func didBecomeActive() {
        super.didBecomeActive()
        didBecomeActiveCalled = true
    }

    override func willResignActive() {
        super.willResignActive()
        willResignActiveCalled = true
    }

    func callPresenterMethod() {
        presenter.doSomething()
    }
}
