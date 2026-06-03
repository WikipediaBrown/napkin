// snippet.hide
import napkin

@MainActor
protocol CounterRouting: ViewableRouting, Sendable {
    // Methods the interactor can invoke to drive child routing.
}

protocol CounterListener: AnyObject, Sendable {
    func counterDidFinish() async
}

protocol CounterPresentableListener: AnyObject, Sendable {
    func didTapIncrement() async
    func didTapDecrement() async
    func didTapDone() async
}

// snippet.show
import napkin

protocol CounterPresentable: Presentable, Sendable {
    @MainActor var listener: CounterPresentableListener? { get set }
    func update(count: Int) async
}

final actor CounterInteractor: PresentableInteractable, CounterPresentableListener {

    nonisolated let lifecycle = InteractorLifecycle()
    nonisolated let presenter: CounterPresentable

    weak var router: CounterRouting?
    weak var listener: CounterListener?

    private var count: Int = 0

    init(presenter: CounterPresentable) {
        self.presenter = presenter
    }

    func wire(router: CounterRouting?, listener: CounterListener?) {
        self.router = router
        self.listener = listener
    }

    func didBecomeActive() async {
        let presenter = self.presenter
        await presenter.update(count: count)
        await MainActor.run { presenter.listener = self }
    }

    func willResignActive() async {
        let presenter = self.presenter
        await MainActor.run { presenter.listener = nil }
    }

    // MARK: - CounterPresentableListener

    func didTapIncrement() async {
        count += 1
        await presenter.update(count: count)
    }

    func didTapDecrement() async {
        count -= 1
        await presenter.update(count: count)
    }

    func didTapDone() async {
        await listener?.counterDidFinish()
    }
}
