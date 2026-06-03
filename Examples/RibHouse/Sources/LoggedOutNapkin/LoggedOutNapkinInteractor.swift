import napkin

@MainActor
protocol LoggedOutNapkinRouting: ViewableRouting, Sendable {}

protocol LoggedOutNapkinPresentable: Presentable, Sendable {
    @MainActor var listener: LoggedOutNapkinPresentableListener? { get set }
}

protocol LoggedOutNapkinListener: AnyObject, Sendable {
    func loggedOutDidTapLogin() async
}

final actor LoggedOutNapkinInteractor: PresentableInteractable, LoggedOutNapkinPresentableListener {

    nonisolated let lifecycle = InteractorLifecycle()
    nonisolated let presenter: LoggedOutNapkinPresentable

    weak var router: LoggedOutNapkinRouting?
    weak var listener: LoggedOutNapkinListener?

    init(presenter: LoggedOutNapkinPresentable) {
        self.presenter = presenter
    }

    func wire(router: LoggedOutNapkinRouting?, listener: LoggedOutNapkinListener?) {
        self.router = router
        self.listener = listener
    }

    func didBecomeActive() async {
        let presenter = self.presenter
        await MainActor.run { presenter.listener = self }
    }

    func willResignActive() async {
        let presenter = self.presenter
        await MainActor.run { presenter.listener = nil }
    }

    // MARK: - LoggedOutNapkinPresentableListener

    func didTapLogin() async {
        await listener?.loggedOutDidTapLogin()
    }
}
