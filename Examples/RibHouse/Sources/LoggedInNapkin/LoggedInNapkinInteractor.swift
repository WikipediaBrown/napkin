import napkin

@MainActor
protocol LoggedInNapkinRouting: ViewableRouting, Sendable {}

protocol LoggedInNapkinPresentable: Presentable, Sendable {
    @MainActor var listener: LoggedInNapkinPresentableListener? { get set }
    func present(pitSummary: String) async
}

protocol LoggedInNapkinListener: AnyObject, Sendable {
    func loggedInDidTapLogout() async
}

final actor LoggedInNapkinInteractor: PresentableInteractable, LoggedInNapkinPresentableListener {

    nonisolated let lifecycle = InteractorLifecycle()
    nonisolated let presenter: LoggedInNapkinPresentable
    nonisolated let user: User
    nonisolated let pitService: PitService

    weak var router: LoggedInNapkinRouting?
    weak var listener: LoggedInNapkinListener?

    init(presenter: LoggedInNapkinPresentable, user: User, pitService: PitService) {
        self.presenter = presenter
        self.user = user
        self.pitService = pitService
    }

    func wire(router: LoggedInNapkinRouting?, listener: LoggedInNapkinListener?) {
        self.router = router
        self.listener = listener
    }

    func didBecomeActive() async {
        let presenter = self.presenter
        await MainActor.run { presenter.listener = self }

        // The pit runs only while someone is logged in.
        await pitService.start()

        // Fan-out subscriber #1: reduce each board snapshot to the header
        // summary. The transform lives in the loop body — this is where a
        // Combine `.map` went. Cancelled automatically on deactivate.
        task {
            for await items in await self.pitService.updates() {
                let smoking = items.count(where: { $0.stage == .smoking })
                let resting = items.count(where: { $0.stage == .resting })
                await self.presenter.present(pitSummary: "\(smoking) SMOKING · \(resting) RESTING")
            }
        }
    }

    func willResignActive() async {
        await pitService.stop()
        let presenter = self.presenter
        await MainActor.run { presenter.listener = nil }
    }

    // MARK: - LoggedInNapkinPresentableListener

    func didTapLogout() async {
        await listener?.loggedInDidTapLogout()
    }
}
