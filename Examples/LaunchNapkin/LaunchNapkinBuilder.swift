//
//  LaunchNapkinBuilder.swift
//  napkin
//
//  Created by nonplus on 3/13/26.
//

import napkin

protocol LaunchNapkinDependency: Dependency {
    // Declare the set of dependencies required by this napkin, but cannot be
    // created by this napkin.
}

final class LaunchNapkinComponent: Component<LaunchNapkinDependency>, @unchecked Sendable {

    // Declare 'fileprivate' dependencies that are only used by this napkin.
}

// MARK: - Builder

protocol LaunchNapkinBuildable: Buildable {
    @MainActor func build(withListener listener: LaunchNapkinListener) async -> LaunchNapkinRouting
}

final class LaunchNapkinBuilder: Builder<LaunchNapkinDependency>, LaunchNapkinBuildable, @unchecked Sendable {

    override init(dependency: LaunchNapkinDependency) {
        super.init(dependency: dependency)
    }

    @MainActor
    func build(withListener listener: LaunchNapkinListener) async -> LaunchNapkinRouting {
        let component = LaunchNapkinComponent(dependency: dependency)
        _ = component
        let viewController = LaunchNapkinViewController()
        let interactor = LaunchNapkinInteractor(presenter: viewController)
        await interactor.set(listener: listener)
        let router = LaunchNapkinRouter(interactor: interactor, viewController: viewController)
        await interactor.set(router: router)
        return router
    }
}

// MARK: - SceneDelegate launch
//
// Use the launch router from your scene delegate (or app delegate). `launch(from:)`
// is async; hop into a Task at the call site:
//
//   func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: ...) {
//       guard let windowScene = scene as? UIWindowScene else { return }
//       let window = UIWindow(windowScene: windowScene)
//       self.window = window
//       let dependency = LaunchDependency()
//       Task { @MainActor in
//           let launchRouter = await LaunchNapkinBuilder(dependency: dependency)
//               .build(withListener: AppListener())
//           await launchRouter.launch(from: window)
//       }
//   }
