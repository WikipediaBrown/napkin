import napkin

@MainActor
protocol PingNapkinRouting: ViewableRouting, Sendable {}

protocol PingNapkinPresentable: Presentable, Sendable {
    @MainActor var listener: PingNapkinPresentableListener? { get set }
    func update(connectedCount: Int?) async
}

protocol PingNapkinListener: AnyObject, Sendable {
    func pingDidTapSwap() async
    func numberOfNapkinsConnected() async -> Int?
}

final actor PingNapkinInteractor: PresentableInteractable, PingNapkinPresentableListener {

    nonisolated let lifecycle = InteractorLifecycle()
    nonisolated let presenter: PingNapkinPresentable

    weak var router: PingNapkinRouting?
    weak var listener: PingNapkinListener?

    init(presenter: PingNapkinPresentable) {
        self.presenter = presenter
    }

    func set(router: PingNapkinRouting?) { self.router = router }
    func set(listener: PingNapkinListener?) { self.listener = listener }

    func didBecomeActive() async {
        // Ask our listener (the LaunchInteractor) how many napkins are
        // currently connected; the answer comes from the launch router's
        // `children` array. Pass through as an optional — the view shows
        // an em-dash when the listener can't answer.
        let count = await listener?.numberOfNapkinsConnected() ?? nil
        await presenter.update(connectedCount: count)
        let presenter = self.presenter
        await MainActor.run { presenter.listener = self }
    }

    func willResignActive() async {
        let presenter = self.presenter
        await MainActor.run { presenter.listener = nil }
    }

    // MARK: - PingNapkinPresentableListener

    func didTapSwap() async {
        await listener?.pingDidTapSwap()
    }
}
