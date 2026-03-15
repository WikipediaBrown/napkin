//
//  LaunchNapkinBuilder.swift
//  napkin
//
//  Created by nonplus on 3/13/26.
//

import napkin

protocol LaunchNapkinDependency: Dependency {
    // TODO: Declare the set of dependencies required by this napkin, but cannot be
    // created by this napkin.
}

final class LaunchNapkinComponent: Component<LaunchNapkinDependency> {

    // TODO: Declare 'fileprivate' dependencies that are only used by this napkin.
}

// MARK: - Builder

protocol LaunchNapkinBuildable: Buildable {
    @MainActor func build(withListener listener: LaunchNapkinListener) -> LaunchNapkinRouting
}

final class LaunchNapkinBuilder: Builder<LaunchNapkinDependency>, LaunchNapkinBuildable {

    init(dependency: LaunchNapkinDependency) {
        super.init(dependency: dependency)
    }

    @MainActor func build(withListener listener: LaunchNapkinListener) -> LaunchNapkinRouting {
        let component = LaunchNapkinComponent(dependency: dependency)
        let viewController = LaunchNapkinViewController()
        let interactor = LaunchNapkinInteractor(presenter: viewController)
        interactor.listener = listener
        return LaunchNapkinRouter(interactor: interactor, viewController: viewController)
    }
}
