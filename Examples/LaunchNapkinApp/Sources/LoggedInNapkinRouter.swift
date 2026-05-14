import napkin

@MainActor
protocol LoggedInNapkinViewControllable: ViewControllable {}

@MainActor
final class LoggedInNapkinRouter:
    ViewableRouter<LoggedInNapkinInteractor, LoggedInNapkinViewControllable>,
    LoggedInNapkinRouting
{
    override init(interactor: LoggedInNapkinInteractor, viewController: LoggedInNapkinViewControllable) {
        super.init(interactor: interactor, viewController: viewController)
    }
}
