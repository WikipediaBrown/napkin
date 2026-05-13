// snippet.hide
import napkin

protocol CounterPresentableListener: AnyObject, Sendable {
    func didTapIncrement() async
    func didTapDecrement() async
    func didTapDone() async
}

protocol CounterPresentable: Presentable, Sendable {
    @MainActor var listener: CounterPresentableListener? { get set }
    func update(count: Int) async
}

protocol CounterListener: AnyObject, Sendable {
    func counterDidFinish() async
}

final actor CounterInteractor: PresentableInteractable, CounterPresentableListener {
    nonisolated let lifecycle = InteractorLifecycle()
    nonisolated let presenter: CounterPresentable

    init(presenter: CounterPresentable) { self.presenter = presenter }
    func didTapIncrement() async {}
    func didTapDecrement() async {}
    func didTapDone() async {}
}

// snippet.show
import napkin

@MainActor
protocol CounterViewControllable: ViewControllable {
    // Methods the router invokes on the view, e.g. presenting child VCs.
}

@MainActor
protocol CounterRouting: ViewableRouting, Sendable {
    // Methods the interactor can invoke to drive child routing.
}

@MainActor
final class CounterRouter:
    ViewableRouter<CounterInteractor, CounterViewControllable>,
    CounterRouting
{
    override init(
        interactor: CounterInteractor,
        viewController: CounterViewControllable
    ) {
        super.init(interactor: interactor, viewController: viewController)
    }
}
