import napkin

@MainActor
protocol LoggedInNapkinViewControllable: ViewControllable {
    func push(_ child: ViewControllable)
}

@MainActor
final class LoggedInNapkinRouter:
    ViewableRouter<LoggedInNapkinInteractor, LoggedInNapkinViewControllable>,
    LoggedInNapkinRouting
{
    // The router holds the user too, so the full chain
    // interactor → router → builder → loggedInRouter carries it.
    let user: User

    private let announcementsBuilder: AnnouncementsNapkinBuildable
    private var announcementsRouter: AnnouncementsNapkinRouting?

    private let pitBoardBuilder: PitBoardNapkinBuildable
    private var pitBoardRouter: PitBoardNapkinRouting?

    init(
        interactor: LoggedInNapkinInteractor,
        viewController: LoggedInNapkinViewControllable,
        user: User,
        announcementsBuilder: AnnouncementsNapkinBuildable,
        pitBoardBuilder: PitBoardNapkinBuildable
    ) {
        self.user = user
        self.announcementsBuilder = announcementsBuilder
        self.pitBoardBuilder = pitBoardBuilder
        super.init(interactor: interactor, viewController: viewController)
    }

    override func didLoad() async {
        await super.didLoad()
        await attachAnnouncements()
    }

    // MARK: - LoggedInNapkinRouting

    func attachPitBoard() async {
        guard pitBoardRouter == nil else { return }
        let router = await pitBoardBuilder.build(withListener: interactor)
        pitBoardRouter = router
        await attachChild(router)
        viewController.push(router.viewControllable)
    }

    func detachPitBoard() async {
        guard let router = pitBoardRouter else { return }
        pitBoardRouter = nil
        // The back button already popped the view; only the logical tree
        // needs closing.
        await detachChild(router)
    }

    // MARK: - Private

    private func attachAnnouncements() async {
        guard announcementsRouter == nil else { return }
        let router = await announcementsBuilder.build(withListener: interactor)
        announcementsRouter = router
        await attachChild(router)
    }
}
