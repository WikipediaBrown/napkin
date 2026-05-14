import napkin

@MainActor
protocol PongNapkinRouting: ViewableRouting, Sendable {}

protocol PongNapkinPresentable: Presentable, Sendable {
    @MainActor var listener: PongNapkinPresentableListener? { get set }
}

protocol PongNapkinListener: AnyObject, Sendable {
    func pongDidTapSwap() async
}

final actor PongNapkinInteractor: PresentableInteractable, PongNapkinPresentableListener {

    nonisolated let lifecycle = InteractorLifecycle()
    nonisolated let presenter: PongNapkinPresentable

    weak var router: PongNapkinRouting?
    weak var listener: PongNapkinListener?

    init(presenter: PongNapkinPresentable) {
        self.presenter = presenter
    }

    func set(router: PongNapkinRouting?) { self.router = router }
    func set(listener: PongNapkinListener?) { self.listener = listener }

    func didBecomeActive() async {
        let presenter = self.presenter
        await MainActor.run { presenter.listener = self }
    }

    func willResignActive() async {
        let presenter = self.presenter
        await MainActor.run { presenter.listener = nil }
    }

    // MARK: - PongNapkinPresentableListener

    func didTapSwap() async {
        await listener?.pongDidTapSwap()
    }
}
