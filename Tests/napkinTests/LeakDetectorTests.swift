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
import UIKit
@testable import napkin

@MainActor
final class LeakDetectorTests: XCTestCase {

    private var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        cancellables = []
        LeakDetector.disableLeakDetectorOverride = true
        #if DEBUG
        LeakDetector.instance.reset()
        #endif
    }

    override func tearDown() {
        cancellables = nil
        LeakDetector.disableLeakDetectorOverride = false
        super.tearDown()
    }

    // MARK: - Singleton Tests

    func testLeakDetector_instance_returnsSingleton() {
        let instance1 = LeakDetector.instance
        let instance2 = LeakDetector.instance

        XCTAssertTrue(instance1 === instance2)
    }

    // MARK: - Status Tests

    func testLeakDetector_initialStatus_isDidComplete() {
        let expectation = expectation(description: "Status emits")
        var receivedStatus: LeakDetectionStatus?

        LeakDetector.instance.status
            .first()
            .sink { status in
                receivedStatus = status
                expectation.fulfill()
            }
            .store(in: &cancellables)

        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedStatus, .DidComplete)
    }

    func testLeakDetector_expectDeallocate_changesStatusToInProgress() {
        let object = TestObject()
        let expectation = expectation(description: "Status changes")
        var receivedStatuses: [LeakDetectionStatus] = []

        LeakDetector.instance.status
            .sink { status in
                receivedStatuses.append(status)
                if receivedStatuses.count == 2 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        LeakDetector.instance.expectDeallocate(object: object)

        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedStatuses.last, .InProgress)
    }

    // MARK: - ExpectDeallocate Tests

    func testLeakDetector_expectDeallocate_returnsHandle() {
        let object = TestObject()

        let handle = LeakDetector.instance.expectDeallocate(object: object)

        XCTAssertNotNil(handle)
    }

    func testLeakDetector_expectDeallocate_handleCanBeCancelled() {
        let object = TestObject()

        let handle = LeakDetector.instance.expectDeallocate(object: object)
        handle.cancel()

        // Should not crash or throw - test passes if it completes
        XCTAssertTrue(true)
    }

    // MARK: - ExpectViewControllerDisappear Tests

    func testLeakDetector_expectViewControllerDisappear_returnsHandle() {
        let viewController = UIViewController()

        let handle = LeakDetector.instance.expectViewControllerDisappear(viewController: viewController)

        XCTAssertNotNil(handle)
    }

    func testLeakDetector_expectViewControllerDisappear_handleCanBeCancelled() {
        let viewController = UIViewController()

        let handle = LeakDetector.instance.expectViewControllerDisappear(viewController: viewController)
        handle.cancel()

        // Should not crash or throw - test passes if it completes
        XCTAssertTrue(true)
    }

    // MARK: - LeakDetectionStatus Tests

    func testLeakDetectionStatus_inProgress_isDistinctFromDidComplete() {
        XCTAssertNotEqual(LeakDetectionStatus.InProgress, LeakDetectionStatus.DidComplete)
    }

    // MARK: - LeakDefaultExpectationTime Tests

    func testLeakDefaultExpectationTime_deallocation_isPositive() {
        XCTAssertGreaterThan(LeakDefaultExpectationTime.deallocation, 0)
    }

    func testLeakDefaultExpectationTime_viewDisappear_isPositive() {
        XCTAssertGreaterThan(LeakDefaultExpectationTime.viewDisappear, 0)
    }

    func testLeakDefaultExpectationTime_viewDisappear_isLongerThanDeallocation() {
        XCTAssertGreaterThan(LeakDefaultExpectationTime.viewDisappear, LeakDefaultExpectationTime.deallocation)
    }
}

// MARK: - Test Doubles

@MainActor
private class TestObject {}
