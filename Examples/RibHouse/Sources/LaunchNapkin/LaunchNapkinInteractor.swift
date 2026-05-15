import napkin

@MainActor
protocol LaunchNapkinRouting: LaunchRouting, Sendable {
    func attachLoggedOut() async
    func attachLoggedIn(user: User) async
}

protocol LaunchNapkinListener: AnyObject, Sendable {}

final actor LaunchNapkinInteractor:
    Interactable,
    LoggedOutNapkinListener,
    LoggedInNapkinListener
{

    nonisolated let lifecycle = InteractorLifecycle()
    nonisolated let authService: AuthService

    weak var router: LaunchNapkinRouting?
    weak var listener: LaunchNapkinListener?

    init(authService: AuthService) {
        self.authService = authService
    }

    func set(router: LaunchNapkinRouting?) { self.router = router }
    func set(listener: LaunchNapkinListener?) { self.listener = listener }

    func didBecomeActive() async {
        await router?.attachLoggedOut()
    }

    func willResignActive() async {}

    // MARK: - LoggedOutNapkinListener

    func loggedOutDidTapLogin() async {
        do {
            let user = try await authService.login()
            await router?.attachLoggedIn(user: user)
        } catch {
            // Login failed — stay on the logged-out screen. Real apps would
            // surface an alert; we keep this demo silent.
        }
    }

    // MARK: - LoggedInNapkinListener

    func loggedInDidTapLogout() async {
        try? await authService.logout()
        await router?.attachLoggedOut()
    }
}
