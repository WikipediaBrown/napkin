import napkin

protocol LaunchNapkinDependency: Dependency {
    // The AuthService is provided by the app's root component (AppComponent
    // in SceneDelegate) and threaded through here. The LaunchNapkin holds
    // the service and exposes it to its interactor; child napkins never see it.
    var authService: AuthService { get }
    var pitService: PitService { get }
}

final class LaunchNapkinComponent: Component<LaunchNapkinDependency>, @unchecked Sendable {

    var authService: AuthService { dependency.authService }
    var pitService: PitService { dependency.pitService }
}

// Child napkin dependency protocols are empty, so the LaunchNapkin's
// component trivially satisfies them.
extension LaunchNapkinComponent: LoggedOutNapkinDependency, LoggedInNapkinDependency {}

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
        let loggedOutBuilder = LoggedOutNapkinBuilder(dependency: component)
        let loggedInBuilder = LoggedInNapkinBuilder(dependency: component)
        let viewController = LaunchNapkinViewController()
        let interactor = LaunchNapkinInteractor(authService: component.authService)
        let router = LaunchNapkinRouter(
            interactor: interactor,
            viewController: viewController,
            loggedOutBuilder: loggedOutBuilder,
            loggedInBuilder: loggedInBuilder
        )
        await interactor.wire(router: router, listener: listener)
        return router
    }
}
