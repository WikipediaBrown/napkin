//
//  QuoteNapkinBuilder.swift
//  napkin
//
//  Created by nonplus on 5/4/26.
//

import napkin

protocol QuoteNapkinDependency: Dependency {
    // Declare the set of dependencies required by this napkin, but cannot be
    // created by this napkin.
}

final class QuoteNapkinComponent: Component<QuoteNapkinDependency>, @unchecked Sendable {

    // Declare 'fileprivate' dependencies that are only used by this napkin.
}

// MARK: - Builder

protocol QuoteNapkinBuildable: Buildable {
    @MainActor func build(withListener listener: QuoteNapkinListener) async -> QuoteNapkinRouting
}

final class QuoteNapkinBuilder:
    Builder<QuoteNapkinDependency>,
    QuoteNapkinBuildable,
    @unchecked Sendable
{

    override init(dependency: QuoteNapkinDependency) {
        super.init(dependency: dependency)
    }

    @MainActor
    func build(withListener listener: QuoteNapkinListener) async -> QuoteNapkinRouting {
        let component = QuoteNapkinComponent(dependency: dependency)
        _ = component
        let viewController = QuoteNapkinViewController()
        let interactor = QuoteNapkinInteractor(presenter: viewController)
        await interactor.set(listener: listener)
        let router = QuoteNapkinRouter(interactor: interactor, viewController: viewController)
        await interactor.set(router: router)
        return router
    }
}
