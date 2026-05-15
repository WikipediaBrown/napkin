import UIKit
import napkin

// Root dependency conforming to the launch napkin's dependency protocol.
// Provides the AuthService at the top of the dependency tree; the
// LaunchNapkin reads it through its dependency.
final class AppComponent: Component<EmptyDependency>, LaunchNapkinDependency, @unchecked Sendable {
    let authService: AuthService

    init(authService: AuthService = BarbecueAuthService()) {
        self.authService = authService
        super.init(dependency: EmptyComponent())
    }
}

// Top-level listener for the launch napkin. LaunchNapkinListener is empty
// (the launch napkin doesn't need to talk back to the app), so this is
// intentionally a no-op.
final class AppListener: LaunchNapkinListener, @unchecked Sendable {}

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?
    private var launchRouter: LaunchNapkinRouting?
    private let listener = AppListener()

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: windowScene)
        self.window = window

        let listener = self.listener
        Task { @MainActor in
            let builder = LaunchNapkinBuilder(dependency: AppComponent())
            let router = await builder.build(withListener: listener)
            self.launchRouter = router
            await router.launch(from: window)
        }
    }
}
