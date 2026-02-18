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

final class InteractorTests: XCTestCase {

    private var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        cancellables = []
    }

    override func tearDown() {
        cancellables = nil
        super.tearDown()
    }

    // MARK: - Initial State Tests

    func testInteractor_initialState_isNotActive() {
        let interactor = TestInteractor()

        XCTAssertFalse(interactor.isActive)
    }

    func testInteractor_initialState_isActiveStreamEmitsFalse() {
        let interactor = TestInteractor()
        let expectation = expectation(description: "Stream emits initial value")
        var receivedValue: Bool?

        interactor.isActiveStream
            .first()
            .sink { value in
                receivedValue = value
                expectation.fulfill()
            }
            .store(in: &cancellables)

        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedValue, false)
    }

    // MARK: - Activation Tests

    func testInteractor_activate_becomesActive() {
        let interactor = TestInteractor()

        interactor.activate()

        XCTAssertTrue(interactor.isActive)
    }

    func testInteractor_activate_callsDidBecomeActive() {
        let interactor = TestInteractor()

        interactor.activate()

        XCTAssertTrue(interactor.didBecomeActiveCalled)
    }

    func testInteractor_activate_emitsTrueOnStream() {
        let interactor = TestInteractor()
        let expectation = expectation(description: "Stream emits true")
        var receivedValues: [Bool] = []

        interactor.isActiveStream
            .sink { value in
                receivedValues.append(value)
                if receivedValues.count == 2 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        interactor.activate()

        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedValues, [false, true])
    }

    func testInteractor_activateWhenAlreadyActive_doesNotCallDidBecomeActiveAgain() {
        let interactor = TestInteractor()
        interactor.activate()
        interactor.didBecomeActiveCalled = false

        interactor.activate()

        XCTAssertFalse(interactor.didBecomeActiveCalled)
    }

    // MARK: - Deactivation Tests

    func testInteractor_deactivate_becomesInactive() {
        let interactor = TestInteractor()
        interactor.activate()

        interactor.deactivate()

        XCTAssertFalse(interactor.isActive)
    }

    func testInteractor_deactivate_callsWillResignActive() {
        let interactor = TestInteractor()
        interactor.activate()

        interactor.deactivate()

        XCTAssertTrue(interactor.willResignActiveCalled)
    }

    func testInteractor_deactivate_emitsFalseOnStream() {
        let interactor = TestInteractor()
        let expectation = expectation(description: "Stream emits false after deactivation")
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

    func testInteractor_deactivateWhenNotActive_doesNotCallWillResignActive() {
        let interactor = TestInteractor()

        interactor.deactivate()

        XCTAssertFalse(interactor.willResignActiveCalled)
    }

    // MARK: - Lifecycle Order Tests

    func testInteractor_activateDeactivateCycle_maintainsCorrectOrder() {
        let interactor = TestInteractor()
        var lifecycleEvents: [String] = []

        interactor.onDidBecomeActive = { lifecycleEvents.append("didBecomeActive") }
        interactor.onWillResignActive = { lifecycleEvents.append("willResignActive") }

        interactor.activate()
        interactor.deactivate()
        interactor.activate()
        interactor.deactivate()

        XCTAssertEqual(lifecycleEvents, [
            "didBecomeActive",
            "willResignActive",
            "didBecomeActive",
            "willResignActive"
        ])
    }
}

// MARK: - Test Doubles

private class TestInteractor: Interactor {
    var didBecomeActiveCalled = false
    var willResignActiveCalled = false
    var onDidBecomeActive: (() -> Void)?
    var onWillResignActive: (() -> Void)?

    override func didBecomeActive() {
        super.didBecomeActive()
        didBecomeActiveCalled = true
        onDidBecomeActive?()
    }

    override func willResignActive() {
        super.willResignActive()
        willResignActiveCalled = true
        onWillResignActive?()
    }
}
