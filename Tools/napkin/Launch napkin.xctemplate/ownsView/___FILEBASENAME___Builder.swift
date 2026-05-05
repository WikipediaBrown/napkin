//___FILEHEADER___

import napkin

protocol ___VARIABLE_productName___Dependency: Dependency {
    // TODO: Declare the set of dependencies required by this napkin, but cannot be
    // created by this napkin.
}

final class ___VARIABLE_productName___Component: Component<___VARIABLE_productName___Dependency>, @unchecked Sendable {

    // TODO: Declare 'fileprivate' dependencies that are only used by this napkin.
}

// MARK: - Builder

protocol ___VARIABLE_productName___Buildable: Buildable {
    @MainActor func build(withListener listener: ___VARIABLE_productName___Listener) async -> ___VARIABLE_productName___Routing
}

final class ___VARIABLE_productName___Builder: Builder<___VARIABLE_productName___Dependency>, ___VARIABLE_productName___Buildable, @unchecked Sendable {

    override init(dependency: ___VARIABLE_productName___Dependency) {
        super.init(dependency: dependency)
    }

    @MainActor
    func build(withListener listener: ___VARIABLE_productName___Listener) async -> ___VARIABLE_productName___Routing {
        let component = ___VARIABLE_productName___Component(dependency: dependency)
        _ = component
        let viewController = ___VARIABLE_productName___ViewController()
        let interactor = ___VARIABLE_productName___Interactor(presenter: viewController)
        await interactor.set(listener: listener)
        let router = ___VARIABLE_productName___Router(interactor: interactor, viewController: viewController)
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
//           let launchRouter = await ___VARIABLE_productName___Builder(dependency: dependency)
//               .build(withListener: AppListener())
//           await launchRouter.launch(from: window)
//       }
//   }
