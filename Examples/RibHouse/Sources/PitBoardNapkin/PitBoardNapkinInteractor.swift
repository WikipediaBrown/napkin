import napkin
import Observation

@MainActor
protocol PitBoardNapkinRouting: ViewableRouting, Sendable {}

protocol PitBoardNapkinListener: AnyObject, Sendable {
    func pitBoardNapkinDidDismiss() async
}

struct PitBoardSection: Sendable, Equatable, Identifiable {
    let id: Int
    let title: String
    let items: [PitItem]
}

protocol PitBoardNapkinPresentable: Presentable, Sendable {
    @MainActor var listener: PitBoardNapkinPresentableListener? { get set }
    func present(sections: [PitBoardSection]) async
    func present(specials: [Special]) async
}

final actor PitBoardNapkinInteractor: PresentableInteractable, PitBoardNapkinPresentableListener {

    nonisolated let lifecycle = InteractorLifecycle()
    nonisolated let presenter: PitBoardNapkinPresentable
    nonisolated let pitService: PitService
    nonisolated let specialsService: SpecialsService

    weak var router: PitBoardNapkinRouting?
    weak var listener: PitBoardNapkinListener?

    init(
        presenter: PitBoardNapkinPresentable,
        pitService: PitService,
        specialsService: SpecialsService
    ) {
        self.presenter = presenter
        self.pitService = pitService
        self.specialsService = specialsService
    }

    func wire(router: PitBoardNapkinRouting?, listener: PitBoardNapkinListener?) {
        self.router = router
        self.listener = listener
    }

    func didBecomeActive() async {
        let presenter = self.presenter
        await MainActor.run { presenter.listener = self }

        await specialsService.start()

        // Fan-out subscriber #2 to the same PitService the LoggedIn header
        // observes — each updates() call is an independent stream. The
        // grouping transform lives in the loop body.
        task {
            for await items in await self.pitService.updates() {
                let sections = PitItem.Stage.allCases.compactMap { stage -> PitBoardSection? in
                    let staged = items.filter { $0.stage == stage }
                    guard !staged.isEmpty else { return nil }
                    return PitBoardSection(id: stage.rawValue, title: stage.label, items: staged)
                }
                await self.presenter.present(sections: sections)
            }
        }

        // Main-actor state via Observations — the @Observable recipe. The
        // loop is bound to the actor that owns the state; each value hops
        // back here for handling. (Hoist + @MainActor closure: iterating
        // Observations from a nonisolated closure crashes the compiler.)
        let specialsService = self.specialsService
        task { @MainActor [weak self] in
            for await specials in Observations({ specialsService.specials }) {
                await self?.forward(specials: specials)
            }
        }
    }

    func willResignActive() async {
        await specialsService.stop()
        let presenter = self.presenter
        await MainActor.run { presenter.listener = nil }
    }

    // MARK: - PitBoardNapkinPresentableListener

    func didDismiss() async {
        await listener?.pitBoardNapkinDidDismiss()
    }

    // MARK: - Private

    private func forward(specials: [Special]) async {
        await presenter.present(specials: specials)
    }
}
