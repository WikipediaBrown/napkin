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

final class ComponentTests: XCTestCase {

    // MARK: - Initialization Tests

    func testComponent_initialization_storesDependency() {
        let dependency = TestDependency()
        let component = TestComponent(dependency: dependency)

        XCTAssertTrue(component.dependency === dependency)
    }

    func testEmptyComponent_initialization_succeeds() {
        let component = EmptyComponent()

        XCTAssertNotNil(component)
    }

    // MARK: - Shared Instance Tests

    func testComponent_shared_returnsSameInstanceOnMultipleCalls() {
        let dependency = TestDependency()
        let component = TestComponent(dependency: dependency)

        let instance1 = component.sharedService
        let instance2 = component.sharedService

        XCTAssertTrue(instance1 === instance2)
    }

    func testComponent_shared_createsDifferentInstancesForDifferentProperties() {
        let dependency = TestDependency()
        let component = TestComponent(dependency: dependency)

        let service1 = component.sharedService
        let service2 = component.anotherSharedService

        XCTAssertFalse(service1 === service2)
    }

    func testComponent_shared_isThreadSafe() {
        let dependency = TestDependency()
        let component = TestComponent(dependency: dependency)
        let expectation = expectation(description: "All concurrent accesses complete")
        expectation.expectedFulfillmentCount = 100

        var instances: [TestService] = []
        let lock = NSLock()

        DispatchQueue.concurrentPerform(iterations: 100) { _ in
            let instance = component.sharedService
            lock.lock()
            instances.append(instance)
            lock.unlock()
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)

        let firstInstance = instances.first!
        XCTAssertTrue(instances.allSatisfy { $0 === firstInstance })
    }

    // MARK: - Optional Shared Instance Tests

    func testComponent_shared_handlesOptionalType() {
        let dependency = TestDependency()
        let component = TestComponent(dependency: dependency)

        let instance1: TestService? = component.optionalSharedService
        let instance2: TestService? = component.optionalSharedService

        XCTAssertNotNil(instance1)
        XCTAssertTrue(instance1 === instance2)
    }

    // MARK: - Component Hierarchy Tests

    func testComponent_childComponent_canAccessParentDependency() {
        let rootDependency = TestDependency()
        let rootComponent = TestComponent(dependency: rootDependency)

        let childComponent = ChildComponent(dependency: rootComponent)

        XCTAssertTrue(childComponent.dependency === rootComponent)
        XCTAssertTrue(childComponent.dependency.testValue == rootComponent.testValue)
    }
}

// MARK: - Test Doubles

private protocol TestDependencyProtocol: Dependency {
    var testValue: String { get }
}

private class TestDependency: TestDependencyProtocol {
    let testValue: String = "test"
}

private class TestService {
    let id = UUID()
}

private class TestComponent: Component<TestDependencyProtocol>, TestDependencyProtocol {

    var testValue: String {
        return dependency.testValue
    }

    var sharedService: TestService {
        return shared { TestService() }
    }

    var anotherSharedService: TestService {
        return shared { TestService() }
    }

    var optionalSharedService: TestService? {
        return shared { TestService() }
    }
}

private class ChildComponent: Component<TestDependencyProtocol> {}
