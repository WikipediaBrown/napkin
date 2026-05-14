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

    // MARK: - PingNapkinListener / PongNapkinListener

    func pingDidTapSwap() async {
        await router?.attachPong()
    }

    func pongDidTapSwap() async {
        await router?.attachPing()
    }

    func numberOfNapkinsConnected() async -> Int? {
        // Hop to the main actor so we compute `count` on the array there
        // instead of sending the non-Sendable `[any Routing]` back here.
        let router = self.router
        return await MainActor.run { router?.children.count }
    }
}
