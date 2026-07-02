import UIKit
import napkin

// Root dependency conforming to the launch napkin's dependency protocol.
// Provides the shared services at the top of the dependency tree; children
// read them through their Dependency protocols.
final class AppComponent: Component<EmptyDependency>, LaunchNapkinDependency, @unchecked Sendable {
    let authService: AuthService
    let pitService: PitService
    let specialsService: SpecialsService

    init(
        authService: AuthService = BarbecueAuthService(),
        specialsService: SpecialsService,
        fastTicks: Bool = ProcessInfo.processInfo.arguments.contains("-fastTicks")
    ) {
        self.authService = authService
        self.pitService = PitService(tickSeconds: fastTicks ? 0.5 : 4)
        self.specialsService = specialsService
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
            let fastTicks = ProcessInfo.processInfo.arguments.contains("-fastTicks")
            let component = AppComponent(
                specialsService: SpecialsService(rotationSeconds: fastTicks ? 0.75 : 6),
                fastTicks: fastTicks
            )
            let builder = LaunchNapkinBuilder(dependency: component)
            let router = await builder.build(withListener: listener)
            self.launchRouter = router
            await router.launch(from: window)
        }
    }
}
