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

final class BuilderTests: XCTestCase {

    // MARK: - Initialization Tests

    func testBuilder_initialization_storesDependency() {
        let dependency = TestDependency()
        let builder = TestBuilder(dependency: dependency)

        XCTAssertTrue(builder.dependency === dependency)
    }

    func testBuilder_conformsToBuildable() {
        let dependency = TestDependency()
        let builder = TestBuilder(dependency: dependency)

        XCTAssertTrue(builder is Buildable)
    }

    // MARK: - Building Tests

    func testBuilder_build_createsRouter() {
        let dependency = TestDependency()
        let builder = TestBuilder(dependency: dependency)

        let router = builder.build()

        XCTAssertNotNil(router)
    }

    func testBuilder_build_usesProvidedDependency() {
        let dependency = TestDependency()
        dependency.testValue = "custom_value"
        let builder = TestBuilder(dependency: dependency)

        let router = builder.build()

        XCTAssertEqual(router.interactor.receivedValue, "custom_value")
    }

    func testBuilder_multipleBuilds_createsDistinctRouters() {
        let dependency = TestDependency()
        let builder = TestBuilder(dependency: dependency)

        let router1 = builder.build()
        let router2 = builder.build()

        XCTAssertFalse(router1 === router2)
    }
}

// MARK: - Test Doubles

private class TestDependency: Dependency {
    var testValue: String = "default"
}

private class TestInteractor: Interactor {
    var receivedValue: String = ""
}

private class TestRouter: Router<TestInteractor> {}

private class TestBuilder: Builder<TestDependency> {

    func build() -> TestRouter {
        let interactor = TestInteractor()
        interactor.receivedValue = dependency.testValue
        return TestRouter(interactor: interactor)
    }
}
