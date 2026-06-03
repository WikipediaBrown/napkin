//___FILEHEADER___

import napkin

@MainActor
protocol ___VARIABLE_productName___Routing: ViewableRouting {
    // TODO: Declare methods the interactor can invoke to manage sub-tree via the router.
    // Routing methods are async because the router is @MainActor and is called from the
    // interactor actor.
}

protocol ___VARIABLE_productName___Presentable: Presentable, Sendable {
    @MainActor var listener: ___VARIABLE_productName___PresentableListener? { get set }
    // TODO: Declare methods the interactor can invoke the presenter to present data.
    // Presentable methods are async because the presenter is @MainActor.
}

protocol ___VARIABLE_productName___Listener: AnyObject, Sendable {
    // TODO: Declare methods the interactor can invoke to communicate with other napkins.
    // Listener methods are async because the parent's interactor is an actor.
}

final actor ___VARIABLE_productName___Interactor: PresentableInteractable, ___VARIABLE_productName___PresentableListener {

    nonisolated let lifecycle = InteractorLifecycle()
    nonisolated let presenter: ___VARIABLE_productName___Presentable

    weak var router: ___VARIABLE_productName___Routing?
    weak var listener: ___VARIABLE_productName___Listener?

    // TODO: Add additional dependencies to constructor. Do not perform any logic
    // in constructor.
    init(presenter: ___VARIABLE_productName___Presentable) {
        self.presenter = presenter
    }

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
        //       for await value in someStream {
        //           await presenter.present(value)
        //       }
        //   }
    }

    func willResignActive() async {
        // TODO: Pause any business logic. Work started with `task { }` in
        // didBecomeActive() is cancelled automatically after this returns.
    }
}
