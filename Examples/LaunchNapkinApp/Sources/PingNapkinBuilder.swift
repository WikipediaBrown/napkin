import napkin

protocol PingNapkinDependency: Dependency {}

final class PingNapkinComponent: Component<PingNapkinDependency>, @unchecked Sendable {}

protocol PingNapkinBuildable: Buildable {
    @MainActor func build(withListener listener: PingNapkinListener) async -> PingNapkinRouting
}

final class PingNapkinBuilder: Builder<PingNapkinDependency>, PingNapkinBuildable, @unchecked Sendable {

    override init(dependency: PingNapkinDependency) {
        super.init(dependency: dependency)
    }

    @MainActor
    func build(withListener listener: PingNapkinListener) async -> PingNapkinRouting {
        let viewController = PingNapkinViewController()
        let interactor = PingNapkinInteractor(presenter: viewController)
        await interactor.set(listener: listener)
        let router = PingNapkinRouter(interactor: interactor, viewController: viewController)
        await interactor.set(router: router)
        return router
    }
}
