//
//  RootBuilder.swift
//  napkin
//
//  Created by nonplus on 3/8/26.
//

import napkin

@MainActor protocol RootDependency: Dependency {
    // TODO: Declare the set of dependencies required by this napkin, but cannot be
    // created by this napkin.
}

@MainActor final class RootComponent: Component<RootDependency> {

    // TODO: Declare 'fileprivate' dependencies that are only used by this napkin.
}

// MARK: - Builder

@MainActor protocol RootBuildable: Buildable {
    func build(withListener listener: RootListener) -> RootRouting
}

@MainActor final class RootBuilder: Builder<RootDependency>, RootBuildable {

    init(dependency: RootDependency) {
        super.init(dependency: dependency)
    }

    func build(withListener listener: RootListener) -> RootRouting {
        let component = RootComponent(dependency: dependency)
        let viewController = RootViewController()
        let interactor = RootInteractor(presenter: viewController)
        interactor.listener = listener
        return RootRouter(interactor: interactor, viewController: viewController)
    }
}
