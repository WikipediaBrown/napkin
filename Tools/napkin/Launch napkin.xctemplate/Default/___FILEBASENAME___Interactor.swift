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

// MARK: - Interactor

final actor ___VARIABLE_productName___Interactor: Interactable {

    nonisolated let lifecycle = InteractorLifecycle()

    weak var router: ___VARIABLE_productName___Routing?
    weak var listener: ___VARIABLE_productName___Listener?

    // TODO: Add additional dependencies to constructor. Do not perform any logic
    // in constructor.
    init() {}

    // Called once by the builder, after the router is built, to set the
    // interactor's weak back-references in a single hop.
    func wire(router: ___VARIABLE_productName___Routing?, listener: ___VARIABLE_productName___Listener?) {
        self.router = router
        self.listener = listener
    }

    // MARK: - Lifecycle

    func didBecomeActive() async {
        // TODO: Implement business logic here.
        //
        // Start lifecycle-bound work with `task { }`. The lifecycle cancels it
        // for you on deactivate — this is napkin's replacement for RIBs'
        // disposeOnDeactivate, so you write no manual teardown:
        //
        //   task {
        //       for await event in eventStream {
        //           // handle each event on the actor
        //       }
        //   }
    }

    func willResignActive() async {
        await router?.cleanupViews()
        // TODO: Pause any business logic. Work started with `task { }` in
        // didBecomeActive() is cancelled automatically after this returns.
    }
}
