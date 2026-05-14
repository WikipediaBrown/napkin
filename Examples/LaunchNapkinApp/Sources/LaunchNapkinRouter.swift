import napkin

@MainActor
protocol LaunchNapkinViewControllable: ViewControllable {
    // Container ops the router calls when swapping which child is on screen.
    func embed(_ child: ViewControllable)
    func detach(_ child: ViewControllable)
}

@MainActor
final class LaunchNapkinRouter:
    LaunchRouter<LaunchNapkinInteractor, LaunchNapkinViewControllable>,
    LaunchNapkinRouting
{

    private let pingBuilder: PingNapkinBuildable
    private let pongBuilder: PongNapkinBuildable
    private var pingRouter: PingNapkinRouting?
    private var pongRouter: PongNapkinRouting?

    init(
        interactor: LaunchNapkinInteractor,
        viewController: LaunchNapkinViewControllable,
        pingBuilder: PingNapkinBuildable,
        pongBuilder: PongNapkinBuildable
    ) {
        self.pingBuilder = pingBuilder
        self.pongBuilder = pongBuilder
        super.init(interactor: interactor, viewController: viewController)
    }

    // MARK: - LaunchNapkinRouting

    func attachPing() async {
        // Tear down the other side first so only one child is ever active.
        await detachPongIfNeeded()
        guard pingRouter == nil else { return }
        let router = await pingBuilder.build(withListener: interactor)
        pingRouter = router
        await attachChild(router)
        viewController.embed(router.viewControllable)
    }

    func attachPong() async {
        await detachPingIfNeeded()
        guard pongRouter == nil else { return }
        let router = await pongBuilder.build(withListener: interactor)
        pongRouter = router
        await attachChild(router)
        viewController.embed(router.viewControllable)
    }

    // MARK: - Private

    private func detachPingIfNeeded() async {
        guard let router = pingRouter else { return }
        pingRouter = nil
        viewController.detach(router.viewControllable)
        await detachChild(router)
    }

    private func detachPongIfNeeded() async {
        guard let router = pongRouter else { return }
        pongRouter = nil
        viewController.detach(router.viewControllable)
        await detachChild(router)
    }
}
