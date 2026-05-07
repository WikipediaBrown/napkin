//
//  CounterNapkinInteractor.swift
//  napkin
//
//  Created by nonplus on 5/4/26.
//

import napkin

@MainActor
protocol CounterNapkinRouting: ViewableRouting, Sendable {
    // Declare methods the interactor can invoke to manage sub-tree via the router.
}

protocol CounterNapkinPresentable: Presentable, Sendable {
    @MainActor var listener: CounterNapkinPresentableListener? { get set }
    func update(count: Int) async
}

protocol CounterNapkinListener: AnyObject, Sendable {
    func counterDidFinish() async
}

final actor CounterNapkinInteractor: PresentableInteractable, CounterNapkinPresentableListener {

    nonisolated let lifecycle = InteractorLifecycle()
    nonisolated let presenter: CounterNapkinPresentable

    weak var router: CounterNapkinRouting?
    weak var listener: CounterNapkinListener?

    private var count: Int = 0

    init(presenter: CounterNapkinPresentable) {
        self.presenter = presenter
    }

    func set(router: CounterNapkinRouting?) {
        self.router = router
    }

    func set(listener: CounterNapkinListener?) {
        self.listener = listener
    }

    func didBecomeActive() async {
        let initialCount = self.count
        let presenter = self.presenter
        await presenter.update(count: initialCount)
        await MainActor.run {
            presenter.listener = self
        }
    }

    func willResignActive() async {
        let presenter = self.presenter
        await MainActor.run {
            presenter.listener = nil
        }
    }

    // MARK: - CounterNapkinPresentableListener

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
