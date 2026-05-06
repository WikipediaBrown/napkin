import Testing
@testable import napkin

@Suite("Interactor")
struct InteractorTests {

    @Test func startsInactive() async {
        let interactor = TestInteractor()
        #expect(await interactor.isActive == false)
    }

    @Test func activateMakesActive() async {
        let interactor = TestInteractor()
        await interactor.activate()
        #expect(await interactor.isActive == true)
    }

    @Test func activateCallsDidBecomeActive() async {
        let interactor = TestInteractor()
        await interactor.activate()
        #expect(await interactor.didBecomeActiveCallCount == 1)
    }

    @Test func activateIsIdempotent() async {
        let interactor = TestInteractor()
        await interactor.activate()
        await interactor.activate()
        #expect(await interactor.didBecomeActiveCallCount == 1)
    }

    @Test func deactivateMakesInactive() async {
        let interactor = TestInteractor()
        await interactor.activate()
        await interactor.deactivate()
        #expect(await interactor.isActive == false)
    }

    @Test func deactivateCallsWillResignActive() async {
        let interactor = TestInteractor()
        await interactor.activate()
        await interactor.deactivate()
        #expect(await interactor.willResignActiveCallCount == 1)
    }

    @Test func deactivateWithoutActivateIsNoop() async {
        let interactor = TestInteractor()
        await interactor.deactivate()
        #expect(await interactor.willResignActiveCallCount == 0)
    }

    @Test func isActiveStreamYieldsCurrentThenChanges() async {
        let interactor = TestInteractor()
        let stream = interactor.isActiveStream
        var iter = stream.makeAsyncIterator()

        let first = await iter.next()
        #expect(first == false)

        await interactor.activate()
        let second = await iter.next()
        #expect(second == true)

        await interactor.deactivate()
        let third = await iter.next()
        #expect(third == false)
    }
}

// MARK: - Helpers

private final actor TestInteractor: Interactable {
    nonisolated let lifecycle = InteractorLifecycle()

    private(set) var didBecomeActiveCallCount = 0
    private(set) var willResignActiveCallCount = 0

    func didBecomeActive() async {
        didBecomeActiveCallCount += 1
    }

    func willResignActive() async {
        willResignActiveCallCount += 1
    }
}
