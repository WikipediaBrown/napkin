// snippet.hide
import napkin

protocol CounterListener: AnyObject, Sendable {
    func counterDidFinish() async
}

protocol CounterPresentableListener: AnyObject, Sendable {
    func didTapIncrement() async
    func didTapDecrement() async
    func didTapDone() async
}

protocol CounterPresentable: Presentable, Sendable {
    @MainActor var listener: CounterPresentableListener? { get set }
    func update(count: Int) async
}

@MainActor
protocol CounterViewControllable: ViewControllable {
    // Methods the router invokes on the view, e.g. presenting child VCs.
}

@MainActor
protocol CounterRouting: ViewableRouting, Sendable {
    // Methods the interactor can invoke to drive child routing.
}

final actor CounterInteractor: PresentableInteractable, CounterPresentableListener {
    nonisolated let lifecycle = InteractorLifecycle()
    nonisolated let presenter: CounterPresentable
    weak var router: CounterRouting?
    weak var listener: CounterListener?

    init(presenter: CounterPresentable) {
        self.presenter = presenter
    }

    func wire(router: CounterRouting?, listener: CounterListener?) {
        self.router = router
        self.listener = listener
    }
    func didTapIncrement() async {}
    func didTapDecrement() async {}
    func didTapDone() async {}
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

#if canImport(UIKit)
import UIKit

@MainActor
final class CounterViewController: UIViewController, CounterPresentable, CounterViewControllable {
    weak var listener: CounterPresentableListener?
    func update(count: Int) async {}
}
#elseif canImport(AppKit)
import AppKit

@MainActor
final class CounterViewController: NSViewController, CounterPresentable, CounterViewControllable {
    weak var listener: CounterPresentableListener?
    func update(count: Int) async {}
}
#endif

// snippet.show
import napkin

protocol CounterDependency: Dependency {
    // Declare the set of services this napkin needs but cannot create itself.
    // Counter is self-contained, so this list is empty.
}

final class CounterComponent: Component<CounterDependency>, @unchecked Sendable {
    // Pass-through services and locally created instances live here.
}

protocol CounterBuildable: Buildable {
    @MainActor func build(withListener listener: CounterListener) async -> CounterRouting
}

final class CounterBuilder:
    Builder<CounterDependency>,
    CounterBuildable,
    @unchecked Sendable
{
    override init(dependency: CounterDependency) {
        super.init(dependency: dependency)
    }

    @MainActor
    func build(withListener listener: CounterListener) async -> CounterRouting {
        let component = CounterComponent(dependency: dependency)
        _ = component
        let viewController = CounterViewController()
        let interactor = CounterInteractor(presenter: viewController)
        let router = CounterRouter(interactor: interactor, viewController: viewController)
        await interactor.wire(router: router, listener: listener)
        return router
    }
}
