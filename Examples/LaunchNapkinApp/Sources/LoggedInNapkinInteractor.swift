import napkin

@MainActor
protocol LoggedInNapkinRouting: ViewableRouting, Sendable {}

protocol LoggedInNapkinPresentable: Presentable, Sendable {
    @MainActor var listener: LoggedInNapkinPresentableListener? { get set }
}

protocol LoggedInNapkinListener: AnyObject, Sendable {
    func loggedInDidTapLogout() async
}

final actor LoggedInNapkinInteractor: PresentableInteractable, LoggedInNapkinPresentableListener {

    nonisolated let lifecycle = InteractorLifecycle()
    nonisolated let presenter: LoggedInNapkinPresentable
    nonisolated let user: User

    weak var router: LoggedInNapkinRouting?
    weak var listener: LoggedInNapkinListener?

    init(presenter: LoggedInNapkinPresentable, user: User) {
        self.presenter = presenter
        self.user = user
    }

    func set(router: LoggedInNapkinRouting?) { self.router = router }
    func set(listener: LoggedInNapkinListener?) { self.listener = listener }

    func didBecomeActive() async {
        let presenter = self.presenter
        await MainActor.run { presenter.listener = self }
    }

    func willResignActive() async {
        let presenter = self.presenter
        await MainActor.run { presenter.listener = nil }
    }

    // MARK: - LoggedInNapkinPresentableListener

    func didTapLogout() async {
        await listener?.loggedInDidTapLogout()
    }
}
