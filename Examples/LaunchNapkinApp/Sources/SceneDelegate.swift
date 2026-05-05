import UIKit
import napkin

// Root dependency conforming to the launch napkin's dependency protocol.
// The launch napkin declares no required dependencies, so an empty
// component is sufficient.
final class AppComponent: Component<EmptyDependency>, LaunchNapkinDependency, @unchecked Sendable {
    init() {
        super.init(dependency: EmptyComponent())
    }
}

// Top-level listener for the launch napkin. The launch napkin declares
// no listener methods, so this is intentionally empty.
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
