import Testing
@testable import napkin

@Suite("Router")
@MainActor
struct RouterTests {

    @Test func startsWithEmptyChildren() {
        let router = TestRouter(interactor: TestInteractor())
        #expect(router.children.isEmpty)
    }

    @Test func loadCallsDidLoadOnce() async {
        let router = TestRouter(interactor: TestInteractor())
        await router.load()
        await router.load()
        #expect(router.didLoadCallCount == 1)
    }

    @Test func loadedReturnsAfterLoad() async {
        let router = TestRouter(interactor: TestInteractor())
        let loadedTask = Task { await router.loaded() }
        await router.load()
        await loadedTask.value
    }

    @Test func loadedReturnsImmediatelyAfterLoaded() async {
        let router = TestRouter(interactor: TestInteractor())
        await router.load()
        await router.loaded()
    }

    @Test func attachChildAddsAndActivates() async {
        let parent = TestRouter(interactor: TestInteractor())
        let child = TestRouter(interactor: TestInteractor())
        await parent.attachChild(child)
        #expect(parent.children.count == 1)
        #expect(parent.children.first === child)
        let childInteractor = child.interactor
        #expect(await childInteractor.isActive == true)
    }

    @Test func detachChildRemovesAndDeactivates() async {
        let parent = TestRouter(interactor: TestInteractor())
        let child = TestRouter(interactor: TestInteractor())
        await parent.attachChild(child)
        await parent.detachChild(child)
        #expect(parent.children.isEmpty)
        let childInteractor = child.interactor
        #expect(await childInteractor.isActive == false)
    }
}

// MARK: - Helpers

@MainActor
private final class TestRouter: napkin.Router<TestInteractor> {
    private(set) var didLoadCallCount = 0

    override func didLoad() async {
        await super.didLoad()
        didLoadCallCount += 1
    }
}

private final actor TestInteractor: Interactable {
    nonisolated let lifecycle = InteractorLifecycle()
}
