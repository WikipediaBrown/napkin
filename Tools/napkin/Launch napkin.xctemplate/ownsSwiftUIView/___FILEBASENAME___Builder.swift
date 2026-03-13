//___FILEHEADER___

import napkin

@MainActor protocol ___VARIABLE_productName___Dependency: Dependency {
    // TODO: Declare the set of dependencies required by this napkin, but cannot be
    // created by this napkin.
}

@MainActor final class ___VARIABLE_productName___Component: Component<___VARIABLE_productName___Dependency> {

    // TODO: Declare 'fileprivate' dependencies that are only used by this napkin.
}

// MARK: - Builder

@MainActor protocol ___VARIABLE_productName___Buildable: Buildable {
    func build(withListener listener: ___VARIABLE_productName___Listener) -> ___VARIABLE_productName___Routing
}

@MainActor final class ___VARIABLE_productName___Builder: Builder<___VARIABLE_productName___Dependency>, ___VARIABLE_productName___Buildable {

    init(dependency: ___VARIABLE_productName___Dependency) {
        super.init(dependency: dependency)
    }

    func build(withListener listener: ___VARIABLE_productName___Listener) -> ___VARIABLE_productName___Routing {
        let component = ___VARIABLE_productName___Component(dependency: dependency)
        let viewController = ___VARIABLE_productName___ViewController()
        let interactor = ___VARIABLE_productName___Interactor(presenter: viewController)
        interactor.listener = listener
        return ___VARIABLE_productName___Router(interactor: interactor, viewController: viewController)
    }
}
