import napkin

protocol LoggedInNapkinDependency: Dependency {}

final class LoggedInNapkinComponent: Component<LoggedInNapkinDependency>, @unchecked Sendable {}

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
        await interactor.set(listener: listener)
        let router = LoggedInNapkinRouter(interactor: interactor, viewController: viewController)
        await interactor.set(router: router)
        return router
    }
}
