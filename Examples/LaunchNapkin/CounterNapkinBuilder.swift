//
//  CounterNapkinBuilder.swift
//  napkin
//
//  Created by nonplus on 5/4/26.
//

import napkin

protocol CounterNapkinDependency: Dependency {
    // Declare the set of dependencies required by this napkin, but cannot be
    // created by this napkin.
}

final class CounterNapkinComponent: Component<CounterNapkinDependency>, @unchecked Sendable {

    // Declare 'fileprivate' dependencies that are only used by this napkin.
}

// MARK: - Builder

protocol CounterNapkinBuildable: Buildable {
    @MainActor func build(withListener listener: CounterNapkinListener) async -> CounterNapkinRouting
}

final class CounterNapkinBuilder:
    Builder<CounterNapkinDependency>,
    CounterNapkinBuildable,
    @unchecked Sendable
{

    override init(dependency: CounterNapkinDependency) {
        super.init(dependency: dependency)
    }

    @MainActor
    func build(withListener listener: CounterNapkinListener) async -> CounterNapkinRouting {
        let component = CounterNapkinComponent(dependency: dependency)
        _ = component
        let viewController = CounterNapkinViewController()
        let interactor = CounterNapkinInteractor(presenter: viewController)
        await interactor.set(listener: listener)
        let router = CounterNapkinRouter(interactor: interactor, viewController: viewController)
        await interactor.set(router: router)
        return router
    }
}
