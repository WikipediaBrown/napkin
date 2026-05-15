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

    init(
        interactor: LoggedInNapkinInteractor,
        viewController: LoggedInNapkinViewControllable,
        user: User
    ) {
        self.user = user
        super.init(interactor: interactor, viewController: viewController)
    }
}
