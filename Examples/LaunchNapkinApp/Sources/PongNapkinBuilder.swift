import napkin

protocol PongNapkinDependency: Dependency {}

final class PongNapkinComponent: Component<PongNapkinDependency>, @unchecked Sendable {}

protocol PongNapkinBuildable: Buildable {
    @MainActor func build(withListener listener: PongNapkinListener) async -> PongNapkinRouting
}

final class PongNapkinBuilder: Builder<PongNapkinDependency>, PongNapkinBuildable, @unchecked Sendable {

    override init(dependency: PongNapkinDependency) {
        super.init(dependency: dependency)
    }

    @MainActor
    func build(withListener listener: PongNapkinListener) async -> PongNapkinRouting {
        let viewController = PongNapkinViewController()
        let interactor = PongNapkinInteractor(presenter: viewController)
        await interactor.set(listener: listener)
        let router = PongNapkinRouter(interactor: interactor, viewController: viewController)
        await interactor.set(router: router)
        return router
    }
}
