import napkin

protocol LoggedOutNapkinDependency: Dependency {}

final class LoggedOutNapkinComponent: Component<LoggedOutNapkinDependency>, @unchecked Sendable {}

protocol LoggedOutNapkinBuildable: Buildable {
    @MainActor func build(withListener listener: LoggedOutNapkinListener) async -> LoggedOutNapkinRouting
}

final class LoggedOutNapkinBuilder: Builder<LoggedOutNapkinDependency>, LoggedOutNapkinBuildable, @unchecked Sendable {

    override init(dependency: LoggedOutNapkinDependency) {
        super.init(dependency: dependency)
    }

    @MainActor
    func build(withListener listener: LoggedOutNapkinListener) async -> LoggedOutNapkinRouting {
        let viewController = LoggedOutNapkinViewController()
        let interactor = LoggedOutNapkinInteractor(presenter: viewController)
        await interactor.set(listener: listener)
        let router = LoggedOutNapkinRouter(interactor: interactor, viewController: viewController)
        await interactor.set(router: router)
        return router
    }
}
