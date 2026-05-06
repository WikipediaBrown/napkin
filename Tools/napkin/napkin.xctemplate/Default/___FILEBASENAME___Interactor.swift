//___FILEHEADER___

import napkin

@MainActor
protocol ___VARIABLE_productName___Routing: Routing {
    func cleanupViews() async
    // TODO: Declare methods the interactor can invoke to manage sub-tree via the router.
    // Routing methods are async because the router is @MainActor and is called from the
    // interactor actor.
}

protocol ___VARIABLE_productName___Listener: AnyObject, Sendable {
    // TODO: Declare methods the interactor can invoke to communicate with other napkins.
    // Listener methods are async because the parent's interactor is an actor.
}

final actor ___VARIABLE_productName___Interactor: Interactable {

    nonisolated let lifecycle = InteractorLifecycle()

    weak var router: ___VARIABLE_productName___Routing?
    weak var listener: ___VARIABLE_productName___Listener?

    // TODO: Add additional dependencies to constructor. Do not perform any logic
    // in constructor.
    init() {}

    func set(router: ___VARIABLE_productName___Routing?) {
        self.router = router
    }

    func set(listener: ___VARIABLE_productName___Listener?) {
        self.listener = listener
    }

    func didBecomeActive() async {
        // TODO: Implement business logic here.
    }

    func willResignActive() async {
        await router?.cleanupViews()
        // TODO: Pause any business logic.
    }
}
