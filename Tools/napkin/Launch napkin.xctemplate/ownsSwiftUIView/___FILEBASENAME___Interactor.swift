//___FILEHEADER___

import napkin

@MainActor
protocol ___VARIABLE_productName___Routing: LaunchRouting {
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
        // TODO: Pause any business logic.
    }
}
