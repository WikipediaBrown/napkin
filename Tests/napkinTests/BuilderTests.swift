import Testing
@testable import napkin

@Suite("Builder")
struct BuilderTests {

    @Test func holdsDependency() {
        let dependency = StubDependency()
        let builder = StubBuilder(dependency: dependency)
        #expect(builder.dependency === dependency)
    }
}

private final class StubDependency: Dependency {}
private final class StubBuilder: Builder<StubDependency>, @unchecked Sendable {}
