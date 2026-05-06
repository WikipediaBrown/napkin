import Testing
@testable import napkin

@Suite("MultiStageComponentizedBuilder")
struct MultiStageComponentizedBuilderTests {

    // MARK: - MultiStageComponentizedBuilder Tests

    @Test func componentForCurrentBuildPassReturnsSameComponentWithinPass() {
        let builder = TestMultiStageBuilder()
        let component1 = builder.componentForCurrentBuildPass
        let component2 = builder.componentForCurrentBuildPass
        #expect(component1 === component2)
    }

    @Test func finalStageBuildReturnsRouter() {
        let builder = TestMultiStageBuilder()
        let router = builder.finalStageBuild(withDynamicDependency: "dependency")
        #expect(router.dependency == "dependency")
    }

    @Test func finalStageBuildClearsCurrentPassComponent() {
        let builder = TestMultiStageBuilder()
        let component1 = builder.componentForCurrentBuildPass
        _ = builder.finalStageBuild(withDynamicDependency: "dependency")
        let component2 = builder.componentForCurrentBuildPass
        #expect(component1 !== component2)
    }

    @Test func multipleBuildPassesCreateNewComponents() {
        let builder = TestMultiStageBuilder()
        let component1 = builder.componentForCurrentBuildPass
        _ = builder.finalStageBuild(withDynamicDependency: "dep1")

        let component2 = builder.componentForCurrentBuildPass
        _ = builder.finalStageBuild(withDynamicDependency: "dep2")

        #expect(component1 !== component2)
    }

    @Test func finalStageBuildPassesDynamicDependency() {
        let builder = TestMultiStageBuilder()
        let router = builder.finalStageBuild(withDynamicDependency: "myDependency")
        #expect(router.dependency == "myDependency")
    }

    // MARK: - SimpleMultiStageComponentizedBuilder Tests

    @Test func simpleComponentForCurrentBuildPassReturnsSameComponentWithinPass() {
        let builder = TestSimpleMultiStageBuilder()
        let component1 = builder.componentForCurrentBuildPass
        let component2 = builder.componentForCurrentBuildPass
        #expect(component1 === component2)
    }

    @Test func simpleFinalStageBuildReturnsRouter() {
        let builder = TestSimpleMultiStageBuilder()
        let router = builder.finalStageBuild()
        _ = router
    }

    @Test func simpleFinalStageBuildClearsCurrentPassComponent() {
        let builder = TestSimpleMultiStageBuilder()
        let component1 = builder.componentForCurrentBuildPass
        _ = builder.finalStageBuild()
        let component2 = builder.componentForCurrentBuildPass
        #expect(component1 !== component2)
    }

    // MARK: - Buildable Protocol Tests

    @Test func conformsToBuildable() {
        let builder = TestMultiStageBuilder()
        #expect((builder as Any) is Buildable)
    }

    @Test func simpleConformsToBuildable() {
        let builder = TestSimpleMultiStageBuilder()
        #expect((builder as Any) is Buildable)
    }
}

// MARK: - Test Doubles

private final class TestComponent: @unchecked Sendable {}

private final class TestRouter: @unchecked Sendable {
    let dependency: String
    init(dependency: String) { self.dependency = dependency }
}

private final class TestMultiStageBuilder:
    MultiStageComponentizedBuilder<TestComponent, TestRouter, String>, @unchecked Sendable {

    init() {
        super.init {
            TestComponent()
        }
    }

    override func finalStageBuild(with component: TestComponent, _ dynamicDependency: String) -> TestRouter {
        return TestRouter(dependency: dynamicDependency)
    }
}

private final class SimpleTestComponent: @unchecked Sendable {}

private final class SimpleTestRouter: @unchecked Sendable {}

private final class TestSimpleMultiStageBuilder:
    SimpleMultiStageComponentizedBuilder<SimpleTestComponent, SimpleTestRouter>, @unchecked Sendable {

    init() {
        super.init {
            SimpleTestComponent()
        }
    }

    override func finalStageBuild(with component: SimpleTestComponent) -> SimpleTestRouter {
        return SimpleTestRouter()
    }
}
