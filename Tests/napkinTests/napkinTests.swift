import Testing
@testable import napkin

@Suite("napkin")
struct napkinTests {

    @Test func dependencyProtocolConformance() {
        let dependency = TestEmptyDependency()
        #expect((dependency as Any) is Dependency)
    }

    @Test func emptyDependencyConformsToDependency() {
        let dependency = TestEmptyDependency()
        #expect((dependency as Any) is EmptyDependency)
    }
}

private final class TestEmptyDependency: EmptyDependency {}
