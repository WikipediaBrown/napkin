//
//  LaunchNapkinInteractor.swift
//  napkin
//
//  Created by nonplus on 3/13/26.
//

import napkin

@MainActor
protocol LaunchNapkinRouting: LaunchRouting, Sendable {
    // Declare methods the interactor can invoke to manage sub-tree via the router.
    // Routing methods are async because the router is @MainActor and is called from
    // the interactor actor.
    func routeToCounter() async
    func routeBackFromCounter() async
    func routeToQuote() async
    func routeBackFromQuote() async
}

protocol LaunchNapkinPresentable: Presentable, Sendable {
    @MainActor var listener: LaunchNapkinPresentableListener? { get set }
    // Declare methods the interactor can invoke the presenter to present data.
    // Presentable methods are async because the presenter is @MainActor.
}

protocol LaunchNapkinListener: AnyObject, Sendable {
    // Declare methods the interactor can invoke to communicate with other napkins.
    // Listener methods are async because the parent's interactor is an actor.
}

final actor LaunchNapkinInteractor:
    PresentableInteractable,
    LaunchNapkinPresentableListener,
    CounterNapkinListener,
    QuoteNapkinListener
{

    nonisolated let lifecycle = InteractorLifecycle()
    nonisolated let presenter: LaunchNapkinPresentable

    weak var router: LaunchNapkinRouting?
    weak var listener: LaunchNapkinListener?

    // Add additional dependencies to constructor. Do not perform any logic
    // in constructor.
    init(presenter: LaunchNapkinPresentable) {
        self.presenter = presenter
    }

    func set(router: LaunchNapkinRouting?) {
        self.router = router
    }

    func set(listener: LaunchNapkinListener?) {
        self.listener = listener
    }

    func didBecomeActive() async {
        let presenter = self.presenter
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

    // MARK: - LaunchNapkinPresentableListener

    func didTapShowCounter() async {
        await router?.routeToCounter()
    }

    func didTapShowQuote() async {
        await router?.routeToQuote()
    }

    // MARK: - CounterNapkinListener

    func counterDidFinish() async {
        await router?.routeBackFromCounter()
    }

    // MARK: - QuoteNapkinListener

    func quoteDidFinish() async {
        await router?.routeBackFromQuote()
    }
}
