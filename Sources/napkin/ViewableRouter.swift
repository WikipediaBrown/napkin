//
//  Copyright (c) 2017. Uber Technologies
//  Licensed under the Apache License, Version 2.0
//

/// A protocol for routers that own and manage a view controller.
@MainActor
public protocol ViewableRouting: Routing {
    var viewControllable: ViewControllable { get }
}

/// A router that owns a view controller. `@MainActor`.
@MainActor
open class ViewableRouter<InteractorType, ViewControllerType>:
    Router<InteractorType>, ViewableRouting {

    public var viewController: ViewControllerType { _viewController }
    public var viewControllable: ViewControllable { _viewControllable }

    public init(interactor: InteractorType, viewController: ViewControllerType) {
        self._viewController = viewController
        guard let viewControllable = viewController as? ViewControllable else {
            fatalError("\(viewController) should conform to \(ViewControllable.self)")
        }
        self._viewControllable = viewControllable
        super.init(interactor: interactor)
    }

    // MARK: - Private

    private let _viewController: ViewControllerType
    private let _viewControllable: ViewControllable
}
