import napkin

@MainActor
protocol LoggedOutNapkinViewControllable: ViewControllable {}

@MainActor
final class LoggedOutNapkinRouter:
    ViewableRouter<LoggedOutNapkinInteractor, LoggedOutNapkinViewControllable>,
    LoggedOutNapkinRouting
{
    override init(interactor: LoggedOutNapkinInteractor, viewController: LoggedOutNapkinViewControllable) {
        super.init(interactor: interactor, viewController: viewController)
    }
}
