import napkin

protocol LoggedInNapkinDependency: Dependency {
    // The AuthService is required from above (LaunchNapkin's component
    // satisfies it). Declaring it here means the LoggedInNapkin can reach
    // the service if it ever needs to call it directly — even though right
    // now only LaunchInteractor invokes login/logout.
    var authService: AuthService { get }
}

final class LoggedInNapkinComponent: Component<LoggedInNapkinDependency>, @unchecked Sendable {

    var authService: AuthService { dependency.authService }
}

protocol LoggedInNapkinBuildable: Buildable {
    @MainActor func build(
        withListener listener: LoggedInNapkinListener,
        user: User
    ) async -> LoggedInNapkinRouting
}

final class LoggedInNapkinBuilder: Builder<LoggedInNapkinDependency>, LoggedInNapkinBuildable, @unchecked Sendable {

    override init(dependency: LoggedInNapkinDependency) {
        super.init(dependency: dependency)
    }

    @MainActor
    func build(
        withListener listener: LoggedInNapkinListener,
        user: User
    ) async -> LoggedInNapkinRouting {
        let viewController = LoggedInNapkinViewController(user: user)
        let interactor = LoggedInNapkinInteractor(presenter: viewController, user: user)
        let router = LoggedInNapkinRouter(
            interactor: interactor,
            viewController: viewController,
            user: user
        )
        await interactor.wire(router: router, listener: listener)
        return router
    }
}
