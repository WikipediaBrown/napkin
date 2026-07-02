import napkin

@MainActor
protocol LoggedInNapkinViewControllable: ViewControllable {}

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

    init(
        interactor: LoggedInNapkinInteractor,
        viewController: LoggedInNapkinViewControllable,
        user: User,
        announcementsBuilder: AnnouncementsNapkinBuildable
    ) {
        self.user = user
        self.announcementsBuilder = announcementsBuilder
        super.init(interactor: interactor, viewController: viewController)
    }

    override func didLoad() async {
        await super.didLoad()
        await attachAnnouncements()
    }

    // MARK: - Private

    private func attachAnnouncements() async {
        guard announcementsRouter == nil else { return }
        let router = await announcementsBuilder.build(withListener: interactor)
        announcementsRouter = router
        await attachChild(router)
    }
}
