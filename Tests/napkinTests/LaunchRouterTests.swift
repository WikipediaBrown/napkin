import Testing
@testable import napkin

#if canImport(UIKit)
import UIKit

@Suite("LaunchRouter")
@MainActor
struct LaunchRouterTests {

    @Test func launchActivatesAndLoads() async {
        let interactor = StubInteractor()
        let vc = StubViewController()
        let router = StubLaunchRouter(interactor: interactor, viewController: vc)
        let window = UIWindow()
        await router.launch(from: window)

        #expect(window.rootViewController === vc)
        #expect(await interactor.isActive == true)
        #expect(router.didLoadCallCount == 1)
    }
}

private final class StubViewController: UIViewController, ViewControllable {}

@MainActor
private final class StubLaunchRouter:
    napkin.LaunchRouter<StubInteractor, StubViewController> {
    private(set) var didLoadCallCount = 0
    override func didLoad() async {
        await super.didLoad()
        didLoadCallCount += 1
    }
}

private final actor StubInteractor: Interactable {
    nonisolated let lifecycle = InteractorLifecycle()
}
#endif
