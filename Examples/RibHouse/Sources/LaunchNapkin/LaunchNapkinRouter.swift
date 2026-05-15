import napkin

@MainActor
protocol LaunchNapkinViewControllable: ViewControllable {
    func embed(_ child: ViewControllable)
    func detach(_ child: ViewControllable)
}

@MainActor
final class LaunchNapkinRouter:
    LaunchRouter<LaunchNapkinInteractor, LaunchNapkinViewControllable>,
    LaunchNapkinRouting
{

    private let loggedOutBuilder: LoggedOutNapkinBuildable
    private let loggedInBuilder: LoggedInNapkinBuildable
    private var loggedOutRouter: LoggedOutNapkinRouting?
    private var loggedInRouter: LoggedInNapkinRouting?

    init(
        interactor: LaunchNapkinInteractor,
        viewController: LaunchNapkinViewControllable,
        loggedOutBuilder: LoggedOutNapkinBuildable,
        loggedInBuilder: LoggedInNapkinBuildable
    ) {
        self.loggedOutBuilder = loggedOutBuilder
        self.loggedInBuilder = loggedInBuilder
        super.init(interactor: interactor, viewController: viewController)
    }

    // MARK: - LaunchNapkinRouting

    func attachLoggedOut() async {
        await detachLoggedInIfNeeded()
        guard loggedOutRouter == nil else { return }
        let router = await loggedOutBuilder.build(withListener: interactor)
        loggedOutRouter = router
        await attachChild(router)
        viewController.embed(router.viewControllable)
    }

    func attachLoggedIn(user: User) async {
        await detachLoggedOutIfNeeded()
        guard loggedInRouter == nil else { return }
        let router = await loggedInBuilder.build(withListener: interactor, user: user)
        loggedInRouter = router
        await attachChild(router)
        viewController.embed(router.viewControllable)
    }

    // MARK: - Private

    private func detachLoggedOutIfNeeded() async {
        guard let router = loggedOutRouter else { return }
        loggedOutRouter = nil
        viewController.detach(router.viewControllable)
        await detachChild(router)
    }

    private func detachLoggedInIfNeeded() async {
        guard let router = loggedInRouter else { return }
        loggedInRouter = nil
        viewController.detach(router.viewControllable)
        await detachChild(router)
    }
}
