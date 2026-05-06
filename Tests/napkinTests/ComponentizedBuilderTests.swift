import Testing
@testable import napkin

@Suite("ComponentizedBuilder")
struct ComponentizedBuilderTests {

    // MARK: - ComponentizedBuilder Tests

    @Test func buildReturnsRouter() {
        let builder = TestComponentizedBuilder()
        let router: TestRouter = builder.build(
            withDynamicBuildDependency: "buildDep",
            dynamicComponentDependency: "componentDep"
        )
        #expect(router.buildDependency == "buildDep")
    }

    @Test func buildCreatesNewComponentEachTime() {
        let builder = TestComponentizedBuilder()
        let (component1, _): (TestComponent, TestRouter) = builder.build(
            withDynamicBuildDependency: "dep1",
            dynamicComponentDependency: "compDep1"
        )
        let (component2, _): (TestComponent, TestRouter) = builder.build(
            withDynamicBuildDependency: "dep2",
            dynamicComponentDependency: "compDep2"
        )
        #expect(component1 !== component2)
    }

    @Test func buildPassesComponentDependencyToComponentBuilder() {
        let builder = TestComponentizedBuilder()
        let (component, _): (TestComponent, TestRouter) = builder.build(
            withDynamicBuildDependency: "buildDep",
            dynamicComponentDependency: "myComponentDep"
        )
        #expect(component.componentDependency == "myComponentDep")
    }

    @Test func buildPassesDynamicBuildDependency() {
        let builder = TestComponentizedBuilder()
        let router: TestRouter = builder.build(
            withDynamicBuildDependency: "myBuildDep",
            dynamicComponentDependency: "compDep"
        )
        #expect(router.buildDependency == "myBuildDep")
    }

    @Test func buildWithTupleReturnsComponentAndRouter() {
        let builder = TestComponentizedBuilder()
        let result: (TestComponent, TestRouter) = builder.build(
            withDynamicBuildDependency: "buildDep",
            dynamicComponentDependency: "compDep"
        )
        _ = result.0
        _ = result.1
    }

    // MARK: - SimpleComponentizedBuilder Tests

    @Test func simpleBuildReturnsRouter() {
        let builder = TestSimpleComponentizedBuilder()
        let router = builder.build()
        _ = router
    }

    @Test func simpleBuildCreatesNewRouterEachTime() {
        let builder = TestSimpleComponentizedBuilder()
        let router1 = builder.build()
        let router2 = builder.build()
        #expect(router1 !== router2)
    }

    // MARK: - Buildable Protocol Tests

    @Test func conformsToBuildable() {
        let builder = TestComponentizedBuilder()
        #expect((builder as Any) is Buildable)
    }

    @Test func simpleConformsToBuildable() {
        let builder = TestSimpleComponentizedBuilder()
        #expect((builder as Any) is Buildable)
    }
}

// MARK: - Test Doubles

private final class TestComponent: @unchecked Sendable {
    let componentDependency: String
    init(dependency: String) { self.componentDependency = dependency }
}

private final class TestRouter: @unchecked Sendable {
    let buildDependency: String
    init(buildDependency: String) { self.buildDependency = buildDependency }
}

private final class TestComponentizedBuilder:
    ComponentizedBuilder<TestComponent, TestRouter, String, String>, @unchecked Sendable {

    init() {
        super.init { dependency in
            TestComponent(dependency: dependency)
        }
    }

    override func build(with component: TestComponent, _ dynamicBuildDependency: String) -> TestRouter {
        return TestRouter(buildDependency: dynamicBuildDependency)
    }
}

private final class SimpleTestComponent: @unchecked Sendable {}

private final class SimpleTestRouter: @unchecked Sendable {}

private final class TestSimpleComponentizedBuilder:
    SimpleComponentizedBuilder<SimpleTestComponent, SimpleTestRouter>, @unchecked Sendable {

    init() {
        super.init {
            SimpleTestComponent()
        }
    }

    override func build(with component: SimpleTestComponent) -> SimpleTestRouter {
        return SimpleTestRouter()
    }
}
