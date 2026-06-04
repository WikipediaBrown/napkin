//___FILEHEADER___

import napkin
import SwiftUI
import UIKit

// napkin's `LaunchRouter` installs the root view controller into a
// `UIWindow` via `launch(from:)`. Under the SwiftUI App lifecycle there is
// no UIWindow to hand it, so we bridge through a scene delegate supplied
// by a `UIApplicationDelegateAdaptor`. The napkin tree owns the window;
// the `WindowGroup` body is intentionally empty.
@main
struct RootApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            // The launch napkin's router owns the real UI (installed into
            // the scene's window below). This view is never shown.
            Color.clear
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let config = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        config.delegateClass = SceneDelegate.self
        return config
    }
}

class SceneDelegate: UIResponder, UIWindowSceneDelegate, RootListener {

    var window: UIWindow?
    var rootRouter: LaunchRouting?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        let window = UIWindow(windowScene: windowScene)
        self.window = window
        Task { @MainActor in
            // TODO: - Add Launch napkin (named "Root" here).
//            let launchComponent = LaunchComponent()
//            rootRouter = await RootBuilder(dependency: launchComponent).build(withListener: self)
//            await rootRouter?.launch(from: window)
        }
    }
}
