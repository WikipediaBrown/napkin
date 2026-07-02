import napkin

#if canImport(UIKit)
import UIKit

// The LoggedIn napkin owns its own navigation stack (the LaunchNapkin just
// embeds this nav controller like any other child view). The nav bar stays
// hidden on the root screen to preserve the original full-bleed look and
// appears automatically on pushed children so they get a back button.
@MainActor
final class LoggedInNapkinNavigationController: UINavigationController,
    UINavigationControllerDelegate,
    LoggedInNapkinViewControllable
{

    init(root: UIViewController) {
        super.init(rootViewController: root)
        delegate = self
        navigationBar.tintColor = UIColor(
            red: 0.500, green: 0.810, blue: 0.600, alpha: 1
        ) // Palette.Dark.moss
    }

    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    nonisolated func navigationController(
        _ navigationController: UINavigationController,
        willShow viewController: UIViewController,
        animated: Bool
    ) {
        MainActor.assumeIsolated {
            let isRoot = viewController === viewControllers.first
            setNavigationBarHidden(isRoot, animated: animated)
        }
    }

    // MARK: - LoggedInNapkinViewControllable

    func push(_ child: ViewControllable) {
        pushViewController(child.uiviewController, animated: true)
    }
}
#endif
