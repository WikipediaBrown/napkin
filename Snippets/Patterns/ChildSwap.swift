// snippet.hide
import napkin

// Stand-in types for the snippet to compile without external context.
@MainActor protocol AlphaNapkinRouting: ViewableRouting, Sendable {}
@MainActor protocol BetaNapkinRouting: ViewableRouting, Sendable {}
protocol AlphaNapkinListener: AnyObject, Sendable {}
protocol BetaNapkinListener: AnyObject, Sendable {}
protocol AlphaNapkinBuildable: Buildable {
    @MainActor func build(withListener listener: AlphaNapkinListener) async -> AlphaNapkinRouting
}
protocol BetaNapkinBuildable: Buildable {
    @MainActor func build(withListener listener: BetaNapkinListener) async -> BetaNapkinRouting
}
@MainActor
protocol SwapParentViewControllable: ViewControllable {
    func embed(_ child: ViewControllable)
    func detach(_ child: ViewControllable)
}
final actor SwapParentInteractor: Interactable, AlphaNapkinListener, BetaNapkinListener {
    nonisolated let lifecycle = InteractorLifecycle()
    func didBecomeActive() async {}
    func willResignActive() async {}
}
@MainActor
protocol SwapParentRouting: ViewableRouting, Sendable {
    func attachAlpha() async
    func attachBeta() async
}
// snippet.show

// Swap routing: two children, only one attached at a time. Each attach
// method tears down the other first. The parent's interactor stays
// stateless about which child is current — the router holds the state.

@MainActor
final class SwapParentRouter:
    ViewableRouter<SwapParentInteractor, SwapParentViewControllable>,
    SwapParentRouting
{
    private let alphaBuilder: AlphaNapkinBuildable
    private let betaBuilder: BetaNapkinBuildable
    private var alphaRouter: AlphaNapkinRouting?
    private var betaRouter: BetaNapkinRouting?

    init(
        interactor: SwapParentInteractor,
        viewController: SwapParentViewControllable,
        alphaBuilder: AlphaNapkinBuildable,
        betaBuilder: BetaNapkinBuildable
    ) {
        self.alphaBuilder = alphaBuilder
        self.betaBuilder = betaBuilder
        super.init(interactor: interactor, viewController: viewController)
    }

    // MARK: - SwapParentRouting

    func attachAlpha() async {
        await detachBetaIfNeeded()
        guard alphaRouter == nil else { return }
        let router = await alphaBuilder.build(withListener: interactor)
        alphaRouter = router
        await attachChild(router)
        viewController.embed(router.viewControllable)
    }

    func attachBeta() async {
        await detachAlphaIfNeeded()
        guard betaRouter == nil else { return }
        let router = await betaBuilder.build(withListener: interactor)
        betaRouter = router
        await attachChild(router)
        viewController.embed(router.viewControllable)
    }

    // MARK: - Private

    private func detachAlphaIfNeeded() async {
        guard let router = alphaRouter else { return }
        alphaRouter = nil
        viewController.detach(router.viewControllable)
        await detachChild(router)
    }

    private func detachBetaIfNeeded() async {
        guard let router = betaRouter else { return }
        betaRouter = nil
        viewController.detach(router.viewControllable)
        await detachChild(router)
    }
}
