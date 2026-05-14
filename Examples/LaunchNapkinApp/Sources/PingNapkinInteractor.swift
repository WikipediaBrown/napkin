import napkin

@MainActor
protocol PingNapkinRouting: ViewableRouting, Sendable {}

protocol PingNapkinPresentable: Presentable, Sendable {
    @MainActor var listener: PingNapkinPresentableListener? { get set }
}

protocol PingNapkinListener: AnyObject, Sendable {
    func pingDidTapSwap() async
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
