import napkin

@MainActor
protocol PongNapkinViewControllable: ViewControllable {}

@MainActor
final class PongNapkinRouter:
    ViewableRouter<PongNapkinInteractor, PongNapkinViewControllable>,
    PongNapkinRouting
{
    override init(interactor: PongNapkinInteractor, viewController: PongNapkinViewControllable) {
        super.init(interactor: interactor, viewController: viewController)
    }
}
