import napkin

@MainActor
protocol PitBoardNapkinViewControllable: ViewControllable {}

@MainActor
final class PitBoardNapkinRouter:
    ViewableRouter<PitBoardNapkinInteractor, PitBoardNapkinViewControllable>,
    PitBoardNapkinRouting
{}
