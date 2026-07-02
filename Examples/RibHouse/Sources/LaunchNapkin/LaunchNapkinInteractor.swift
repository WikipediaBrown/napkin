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

    func wire(router: LaunchNapkinRouting?, listener: LaunchNapkinListener?) {
        self.router = router
        self.listener = listener
    }

    func didBecomeActive() async {
        // The auth gate: routing follows auth state, not taps. The stream
        // replays the current value (nil at launch), which is what attaches
        // the LoggedOut napkin. Bound to the active scope — cancelled
        // automatically on willResignActive.
        task {
            for await user in await self.authService.userStream() {
                if let user {
                    await self.router?.attachLoggedIn(user: user)
                } else {
                    await self.router?.attachLoggedOut()
                }
            }
        }
    }

    func willResignActive() async {}

    // MARK: - LoggedOutNapkinListener

    func loggedOutDidTapLogin() async {
        do {
            _ = try await authService.login()
            // No routing here — the gate above reacts to the stream.
        } catch {
            // Login failed — stay on the logged-out screen. Real apps would
            // surface an alert; we keep this demo silent.
        }
    }

    // MARK: - LoggedInNapkinListener

    func loggedInDidTapLogout() async {
        // Routing happens via the stream, same as login.
        try? await authService.logout()
    }
}
