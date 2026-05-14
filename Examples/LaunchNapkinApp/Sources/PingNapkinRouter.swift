import napkin

@MainActor
protocol PingNapkinViewControllable: ViewControllable {}

@MainActor
final class PingNapkinRouter:
    ViewableRouter<PingNapkinInteractor, PingNapkinViewControllable>,
    PingNapkinRouting
{
    override init(interactor: PingNapkinInteractor, viewController: PingNapkinViewControllable) {
        super.init(interactor: interactor, viewController: viewController)
    }
}
