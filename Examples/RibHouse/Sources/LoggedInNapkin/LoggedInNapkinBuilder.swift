import napkin

protocol LoggedInNapkinDependency: Dependency {
    // Threaded from the AppComponent through the LaunchNapkin. The pit
    // powers the live summary here and the PitBoard child.
    var authService: AuthService { get }
    var pitService: PitService { get }
}

final class LoggedInNapkinComponent: Component<LoggedInNapkinDependency>, @unchecked Sendable {

    var authService: AuthService { dependency.authService }
    var pitService: PitService { dependency.pitService }
}

extension LoggedInNapkinComponent: AnnouncementsNapkinDependency {}

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
        let component = LoggedInNapkinComponent(dependency: dependency)
        let hosting = LoggedInNapkinViewController(user: user)
        let navigation = LoggedInNapkinNavigationController(root: hosting)
        let interactor = LoggedInNapkinInteractor(
            presenter: hosting,
            user: user,
            pitService: component.pitService
        )
        let announcementsBuilder = AnnouncementsNapkinBuilder(dependency: component)
        let router = LoggedInNapkinRouter(
            interactor: interactor,
            viewController: navigation,
            user: user,
            announcementsBuilder: announcementsBuilder
        )
        await interactor.wire(router: router, listener: listener)
        return router
    }
}
