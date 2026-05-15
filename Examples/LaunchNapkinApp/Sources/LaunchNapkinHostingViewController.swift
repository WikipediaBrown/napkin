import napkin

#if canImport(UIKit)
import UIKit

@MainActor
final class LaunchNapkinViewController: UIViewController, LaunchNapkinViewControllable {

    private weak var currentChild: UIViewController?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        view.accessibilityIdentifier = NapkinAccessibility.Launch.container
    }

    // MARK: - LaunchNapkinViewControllable

    func embed(_ child: ViewControllable) {
        let childVC = child.uiviewController
        addChild(childVC)
        childVC.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(childVC.view)
        NSLayoutConstraint.activate([
            childVC.view.topAnchor.constraint(equalTo: view.topAnchor),
            childVC.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            childVC.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            childVC.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        childVC.didMove(toParent: self)
        currentChild = childVC
    }

    func detach(_ child: ViewControllable) {
        let childVC = child.uiviewController
        childVC.willMove(toParent: nil)
        childVC.view.removeFromSuperview()
        childVC.removeFromParent()
        if currentChild === childVC { currentChild = nil }
    }
}

#elseif canImport(AppKit)
import AppKit

@MainActor
final class LaunchNapkinViewController: NSViewController, LaunchNapkinViewControllable {

    private weak var currentChild: NSViewController?

    override func loadView() {
        view = NSView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.setAccessibilityIdentifier(NapkinAccessibility.Launch.container)
    }

    // MARK: - LaunchNapkinViewControllable

    func embed(_ child: ViewControllable) {
        let childVC = child.nsviewController
        addChild(childVC)
        childVC.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(childVC.view)
        NSLayoutConstraint.activate([
            childVC.view.topAnchor.constraint(equalTo: view.topAnchor),
            childVC.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            childVC.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            childVC.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        currentChild = childVC
    }

    func detach(_ child: ViewControllable) {
        let childVC = child.nsviewController
        childVC.view.removeFromSuperview()
        childVC.removeFromParent()
        if currentChild === childVC { currentChild = nil }
    }
}
#endif
