//___FILEHEADER___

import napkin
import Combine

protocol ___VARIABLE_productName___Routing: Routing {
    func cleanupViews()
    // TODO: Declare methods the interactor can invoke to manage sub-tree via the router.
}

protocol ___VARIABLE_productName___Listener: AnyObject {
    // TODO: Declare methods the interactor can invoke to communicate with other napkins.
}

final class ___VARIABLE_productName___Interactor: Interactor, ___VARIABLE_productName___Interactable {

    weak var router: ___VARIABLE_productName___Routing?
    weak var listener: ___VARIABLE_productName___Listener?

    // TODO: Add additional dependencies to constructor. Do not perform any logic
    // in constructor.
    nonisolated override init() {}

    nonisolated override func didBecomeActive() {
        super.didBecomeActive()
        // TODO: Implement business logic here.
    }

    nonisolated override func willResignActive() {
        super.willResignActive()

        router?.cleanupViews()
        // TODO: Pause any business logic.
    }
}
