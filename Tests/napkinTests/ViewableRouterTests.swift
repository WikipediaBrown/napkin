import Testing
@testable import napkin

#if canImport(UIKit)
import UIKit

@Suite("ViewableRouter")
@MainActor
struct ViewableRouterTests {

    @Test func holdsViewController() {
        let vc = StubViewController()
        let router = StubViewableRouter(interactor: StubInteractor(), viewController: vc)
        #expect(router.viewController === vc)
        #expect(router.viewControllable === vc)
    }
}

private final class StubViewController: UIViewController, ViewControllable {}

@MainActor
private final class StubViewableRouter:
    napkin.ViewableRouter<StubInteractor, StubViewController> {}

private final actor StubInteractor: Interactable {
    nonisolated let lifecycle = InteractorLifecycle()
}
#endif
