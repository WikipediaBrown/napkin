// snippet.hide
import napkin
#if canImport(UIKit)
import UIKit
#endif
// snippet.show

// A headless napkin: a parent that orchestrates children but has no view of
// its own. The view controller is a plain UIViewController that embeds
// whichever child is currently attached. Useful for auth gates, tab roots,
// onboarding flows, anything that routes without rendering its own UI.

@MainActor
protocol HeadlessParentViewControllable: ViewControllable {
    func embed(_ child: ViewControllable)
    func detach(_ child: ViewControllable)
}

#if canImport(UIKit)
@MainActor
final class HeadlessParentViewController: UIViewController, HeadlessParentViewControllable {

    func embed(_ child: ViewControllable) {
        let vc = child.uiviewController
        addChild(vc)
        vc.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(vc.view)
        NSLayoutConstraint.activate([
            vc.view.topAnchor.constraint(equalTo: view.topAnchor),
            vc.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            vc.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            vc.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        vc.didMove(toParent: self)
    }

    func detach(_ child: ViewControllable) {
        let vc = child.uiviewController
        vc.willMove(toParent: nil)
        vc.view.removeFromSuperview()
        vc.removeFromParent()
    }
}
#endif
