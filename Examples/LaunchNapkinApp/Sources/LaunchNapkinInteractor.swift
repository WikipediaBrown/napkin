import napkin

@MainActor
protocol LaunchNapkinRouting: LaunchRouting, Sendable {
    func attachPing() async
    func attachPong() async
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
        await router?.attachPing()
    }

    func willResignActive() async {}

    // MARK: - PingNapkinListener

    // Ping just told us it was tapped — replace it with Pong. The router
    // tears down Ping as part of attachPong().
    func pingDidTapSwap() async {
        await router?.attachPong()
    }

    // MARK: - PongNapkinListener

    func pongDidTapSwap() async {
        await router?.attachPing()
    }
}
