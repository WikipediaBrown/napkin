import napkin

@MainActor
protocol LaunchNapkinRouting: LaunchRouting, Sendable {
    func attachPing() async
    func swap() async
}

protocol LaunchNapkinListener: AnyObject, Sendable {}

final actor LaunchNapkinInteractor:
    Interactable,
    PingNapkinListener,
    PongNapkinListener
{

    nonisolated let lifecycle = InteractorLifecycle()

    weak var router: LaunchNapkinRouting?
    weak var listener: LaunchNapkinListener?

    func set(router: LaunchNapkinRouting?) { self.router = router }
    func set(listener: LaunchNapkinListener?) { self.listener = listener }

    func didBecomeActive() async {
        // Start with Ping attached. Subsequent swap requests from either child
        // will flip back and forth.
        await router?.attachPing()
    }

    func willResignActive() async {}

    // MARK: - PingNapkinListener

    func pingDidTapSwap() async {
        await router?.swap()
    }

    // MARK: - PongNapkinListener

    func pongDidTapSwap() async {
        await router?.swap()
    }
}
