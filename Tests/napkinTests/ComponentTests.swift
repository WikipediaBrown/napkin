import Testing
@testable import napkin

@Suite("Component")
struct ComponentTests {

    @Test func holdsDependency() {
        let parent = ParentDependency()
        let component = ChildComponent(dependency: parent)
        #expect(component.dependency === parent)
    }

    @Test func sharedReturnsSameInstance() {
        let component = ChildComponent(dependency: ParentDependency())
        let first = component.sharedService
        let second = component.sharedService
        #expect(first === second)
    }

    @Test func nonSharedReturnsNewInstance() {
        let component = ChildComponent(dependency: ParentDependency())
        let first = component.freshService
        let second = component.freshService
        #expect(first !== second)
    }

    @Test func sharedIsThreadSafe() async {
        let component = ChildComponent(dependency: ParentDependency())
        let first = component.sharedService
        await withTaskGroup(of: ObjectIdentifier.self) { group in
            for _ in 0..<32 {
                group.addTask {
                    ObjectIdentifier(component.sharedService)
                }
            }
            for await id in group {
                #expect(id == ObjectIdentifier(first))
            }
        }
    }
}

private final class ParentDependency: Dependency {}

private final class Service {}

private final class ChildComponent: Component<ParentDependency>, @unchecked Sendable {
    var sharedService: Service { shared { Service() } }
    var freshService: Service { Service() }
}
