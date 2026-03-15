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

final class ComponentizedBuilderTests: XCTestCase {

    // MARK: - ComponentizedBuilder Tests

    func testComponentizedBuilder_build_returnsRouter() {
        let builder = TestComponentizedBuilder()

        let router: TestRouter = builder.build(withDynamicBuildDependency: "buildDep", dynamicComponentDependency: "componentDep")

        XCTAssertNotNil(router)
    }

    func testComponentizedBuilder_build_createsNewComponentEachTime() {
        let builder = TestComponentizedBuilder()

        let (component1, _) = builder.build(withDynamicBuildDependency: "dep1", dynamicComponentDependency: "compDep1") as (TestComponent, TestRouter)
        let (component2, _) = builder.build(withDynamicBuildDependency: "dep2", dynamicComponentDependency: "compDep2") as (TestComponent, TestRouter)

        XCTAssertFalse(component1 === component2)
    }

    func testComponentizedBuilder_build_passesComponentDependencyToComponentBuilder() {
        let builder = TestComponentizedBuilder()

        let (component, _) = builder.build(withDynamicBuildDependency: "buildDep", dynamicComponentDependency: "myComponentDep") as (TestComponent, TestRouter)

        XCTAssertEqual(component.componentDependency, "myComponentDep")
    }

    func testComponentizedBuilder_build_passesDynamicBuildDependency() {
        let builder = TestComponentizedBuilder()

        let router: TestRouter = builder.build(withDynamicBuildDependency: "myBuildDep", dynamicComponentDependency: "compDep")

        XCTAssertEqual(router.buildDependency, "myBuildDep")
    }

    func testComponentizedBuilder_buildWithTuple_returnsComponentAndRouter() {
        let builder = TestComponentizedBuilder()

        let result: (TestComponent, TestRouter) = builder.build(withDynamicBuildDependency: "buildDep", dynamicComponentDependency: "compDep")

        XCTAssertNotNil(result.0)
        XCTAssertNotNil(result.1)
    }

    // MARK: - SimpleComponentizedBuilder Tests

    func testSimpleComponentizedBuilder_build_returnsRouter() {
        let builder = TestSimpleComponentizedBuilder()

        let router = builder.build()

        XCTAssertNotNil(router)
    }

    func testSimpleComponentizedBuilder_build_createsNewComponentEachTime() {
        let builder = TestSimpleComponentizedBuilder()

        let router1 = builder.build()
        let router2 = builder.build()

        // Each build creates a new component, so routers should be different instances
        XCTAssertFalse(router1 === router2)
    }

    // MARK: - Buildable Protocol Tests

    func testComponentizedBuilder_conformsToBuildable() {
        let builder = TestComponentizedBuilder()

        XCTAssertTrue((builder as Any) is Buildable)
    }

    func testSimpleComponentizedBuilder_conformsToBuildable() {
        let builder = TestSimpleComponentizedBuilder()

        XCTAssertTrue((builder as Any) is Buildable)
    }
}

// MARK: - Test Doubles

private class TestComponent {
    let componentDependency: String

    init(dependency: String) {
        self.componentDependency = dependency
    }
}

private class TestRouter {
    let buildDependency: String

    init(buildDependency: String) {
        self.buildDependency = buildDependency
    }
}

private class TestComponentizedBuilder: ComponentizedBuilder<TestComponent, TestRouter, String, String> {

    init() {
        super.init { dependency in
            TestComponent(dependency: dependency)
        }
    }

    override func build(with component: TestComponent, _ dynamicBuildDependency: String) -> TestRouter {
        return TestRouter(buildDependency: dynamicBuildDependency)
    }
}

private class SimpleTestComponent {}

private class SimpleTestRouter {}

private class TestSimpleComponentizedBuilder: SimpleComponentizedBuilder<SimpleTestComponent, SimpleTestRouter> {

    init() {
        super.init {
            SimpleTestComponent()
        }
    }

    override func build(with component: SimpleTestComponent) -> SimpleTestRouter {
        return SimpleTestRouter()
    }
}
