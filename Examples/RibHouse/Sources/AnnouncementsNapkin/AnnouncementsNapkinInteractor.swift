import napkin

@MainActor
protocol AnnouncementsNapkinRouting: Routing, Sendable {}

protocol AnnouncementsNapkinListener: AnyObject, Sendable {
    func announcementsNapkinDidHearLastCall(itemName: String) async
}

// Headless consumer of the pit's no-replay event stream — the README's
// PassthroughSubject recipe, live. No view, no presenter: it turns pit
// events into business intents for its parent.
final actor AnnouncementsNapkinInteractor: Interactable {

    nonisolated let lifecycle = InteractorLifecycle()
    nonisolated let pitService: PitService

    weak var router: AnnouncementsNapkinRouting?
    weak var listener: AnnouncementsNapkinListener?

    init(pitService: PitService) {
        self.pitService = pitService
    }

    func wire(router: AnnouncementsNapkinRouting?, listener: AnnouncementsNapkinListener?) {
        self.router = router
        self.listener = listener
    }

    func didBecomeActive() async {
        task {
            for await event in await self.pitService.events() {
                if case .lastCall(let itemName) = event {
                    await self.listener?.announcementsNapkinDidHearLastCall(itemName: itemName)
                }
            }
        }
    }

    func willResignActive() async {}
}
