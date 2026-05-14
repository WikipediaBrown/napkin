import napkin

protocol LaunchNapkinDependency: Dependency {}

final class LaunchNapkinComponent: Component<LaunchNapkinDependency>, @unchecked Sendable {}

// Both child napkins have empty dependency protocols, so the LaunchNapkin's
// component trivially satisfies them.
extension LaunchNapkinComponent: PingNapkinDependency, PongNapkinDependency {}

protocol LaunchNapkinBuildable: Buildable {
    @MainActor func build(withListener listener: LaunchNapkinListener) async -> LaunchNapkinRouting
}

final class LaunchNapkinBuilder: Builder<LaunchNapkinDependency>, LaunchNapkinBuildable, @unchecked Sendable {

    override init(dependency: LaunchNapkinDependency) {
        super.init(dependency: dependency)
    }

    @MainActor
    func build(withListener listener: LaunchNapkinListener) async -> LaunchNapkinRouting {
        let component = LaunchNapkinComponent(dependency: dependency)
        let pingBuilder = PingNapkinBuilder(dependency: component)
        let pongBuilder = PongNapkinBuilder(dependency: component)
        let viewController = LaunchNapkinViewController()
        let interactor = LaunchNapkinInteractor()
        await interactor.set(listener: listener)
        let router = LaunchNapkinRouter(
            interactor: interactor,
            viewController: viewController,
            pingBuilder: pingBuilder,
            pongBuilder: pongBuilder
        )
        await interactor.set(router: router)
        return router
    }
}
