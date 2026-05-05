import Testing
@testable import napkin

@Suite("PresentableInteractable")
struct PresentableInteractableTests {

    @Test func holdsPresenter() async {
        let presenter = StubPresenter()
        let interactor = StubPresentableInteractor(presenter: presenter)
        #expect(interactor.presenter === presenter)
    }

    @Test func inheritsLifecycle() async {
        let interactor = StubPresentableInteractor(presenter: StubPresenter())
        await interactor.activate()
        #expect(await interactor.isActive == true)
        await interactor.deactivate()
        #expect(await interactor.isActive == false)
    }
}

// MARK: - Helpers

@MainActor
final class StubPresenter {}

final actor StubPresentableInteractor: PresentableInteractable {
    nonisolated let lifecycle = InteractorLifecycle()
    nonisolated let presenter: StubPresenter
    init(presenter: StubPresenter) { self.presenter = presenter }
}
