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
        guard pingRouter == nil else { return }
        let router = await pingBuilder.build(withListener: interactor)
        pingRouter = router
        await attachChild(router)
        viewController.embed(router.viewControllable)
    }

    func swap() async {
        if let ping = pingRouter {
            viewController.detach(ping.viewControllable)
            await detachChild(ping)
            pingRouter = nil

            let router = await pongBuilder.build(withListener: interactor)
            pongRouter = router
            await attachChild(router)
            viewController.embed(router.viewControllable)
        } else if let pong = pongRouter {
            viewController.detach(pong.viewControllable)
            await detachChild(pong)
            pongRouter = nil

            let router = await pingBuilder.build(withListener: interactor)
            pingRouter = router
            await attachChild(router)
            viewController.embed(router.viewControllable)
        }
    }
}
