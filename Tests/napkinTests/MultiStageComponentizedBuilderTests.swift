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
final class MultiStageComponentizedBuilderTests: XCTestCase {

    // MARK: - MultiStageComponentizedBuilder Tests

    func testMultiStageComponentizedBuilder_componentForCurrentBuildPass_returnsSameComponentWithinPass() {
        let builder = TestMultiStageBuilder()

        let component1 = builder.componentForCurrentBuildPass
        let component2 = builder.componentForCurrentBuildPass

        XCTAssertTrue(component1 === component2)
    }

    func testMultiStageComponentizedBuilder_finalStageBuild_returnsRouter() {
        let builder = TestMultiStageBuilder()

        let router = builder.finalStageBuild(withDynamicDependency: "dependency")

        XCTAssertNotNil(router)
    }

    func testMultiStageComponentizedBuilder_finalStageBuild_clearsCurrentPassComponent() {
        let builder = TestMultiStageBuilder()

        let component1 = builder.componentForCurrentBuildPass
        _ = builder.finalStageBuild(withDynamicDependency: "dependency")
        let component2 = builder.componentForCurrentBuildPass

        XCTAssertFalse(component1 === component2)
    }

    func testMultiStageComponentizedBuilder_multipleBuildPasses_createNewComponents() {
        let builder = TestMultiStageBuilder()

        let component1 = builder.componentForCurrentBuildPass
        _ = builder.finalStageBuild(withDynamicDependency: "dep1")

        let component2 = builder.componentForCurrentBuildPass
        _ = builder.finalStageBuild(withDynamicDependency: "dep2")

        XCTAssertFalse(component1 === component2)
    }

    func testMultiStageComponentizedBuilder_finalStageBuild_passesDynamicDependency() {
        let builder = TestMultiStageBuilder()

        let router = builder.finalStageBuild(withDynamicDependency: "myDependency")

        XCTAssertEqual(router.dependency, "myDependency")
    }

    // MARK: - SimpleMultiStageComponentizedBuilder Tests

    func testSimpleMultiStageComponentizedBuilder_componentForCurrentBuildPass_returnsSameComponentWithinPass() {
        let builder = TestSimpleMultiStageBuilder()

        let component1 = builder.componentForCurrentBuildPass
        let component2 = builder.componentForCurrentBuildPass

        XCTAssertTrue(component1 === component2)
    }

    func testSimpleMultiStageComponentizedBuilder_finalStageBuild_returnsRouter() {
        let builder = TestSimpleMultiStageBuilder()

        let router = builder.finalStageBuild()

        XCTAssertNotNil(router)
    }

    func testSimpleMultiStageComponentizedBuilder_finalStageBuild_clearsCurrentPassComponent() {
        let builder = TestSimpleMultiStageBuilder()

        let component1 = builder.componentForCurrentBuildPass
        _ = builder.finalStageBuild()
        let component2 = builder.componentForCurrentBuildPass

        XCTAssertFalse(component1 === component2)
    }

    // MARK: - Buildable Protocol Tests

    func testMultiStageComponentizedBuilder_conformsToBuildable() {
        let builder = TestMultiStageBuilder()

        XCTAssertTrue(builder is Buildable)
    }

    func testSimpleMultiStageComponentizedBuilder_conformsToBuildable() {
        let builder = TestSimpleMultiStageBuilder()

        XCTAssertTrue(builder is Buildable)
    }
}

// MARK: - Test Doubles

@MainActor
private class TestComponent {}

@MainActor
private class TestRouter {
    let dependency: String

    init(dependency: String) {
        self.dependency = dependency
    }
}

@MainActor
private class TestMultiStageBuilder: MultiStageComponentizedBuilder<TestComponent, TestRouter, String> {

    init() {
        super.init {
            TestComponent()
        }
    }

    override func finalStageBuild(with component: TestComponent, _ dynamicDependency: String) -> TestRouter {
        return TestRouter(dependency: dynamicDependency)
    }
}

@MainActor
private class SimpleTestComponent {}

@MainActor
private class SimpleTestRouter {}

@MainActor
private class TestSimpleMultiStageBuilder: SimpleMultiStageComponentizedBuilder<SimpleTestComponent, SimpleTestRouter> {

    init() {
        super.init {
            SimpleTestComponent()
        }
    }

    override func finalStageBuild(with component: SimpleTestComponent) -> SimpleTestRouter {
        return SimpleTestRouter()
    }
}
