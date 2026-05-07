// snippet.hide
import napkin

struct User: Sendable {
    let firstName: String
    let lastName: String
}

protocol UserService: Sendable {
    var currentUser: User { get async }
}

protocol ProfileListener: AnyObject, Sendable {
    func profileDidFinish() async
}

protocol ProfilePresentableListener: AnyObject, Sendable {
    func didTapDone() async
}

protocol ProfilePresentable: Presentable, Sendable {
    @MainActor var listener: ProfilePresentableListener? { get set }
    func update(displayName: String) async
}

@MainActor
protocol ProfileViewControllable: ViewControllable {
    // Methods the router invokes on the view, e.g. presenting child VCs.
}

@MainActor
protocol ProfileRouting: ViewableRouting, Sendable {
    // Methods the interactor can invoke to drive child routing.
}

final actor ProfileInteractor: PresentableInteractable, ProfilePresentableListener {
    nonisolated let lifecycle = InteractorLifecycle()
    nonisolated let presenter: ProfilePresentable
    weak var listener: ProfileListener?

    init(presenter: ProfilePresentable, userService: UserService) {
        self.presenter = presenter
    }

    func set(router: ProfileRouting?) {}
    func set(listener: ProfileListener?) { self.listener = listener }
    func didTapDone() async {}
}

@MainActor
final class ProfileRouter:
    ViewableRouter<ProfileInteractor, ProfileViewControllable>,
    ProfileRouting
{
    override init(
        interactor: ProfileInteractor,
        viewController: ProfileViewControllable
    ) {
        super.init(interactor: interactor, viewController: viewController)
    }
}

#if canImport(UIKit)
import UIKit

@MainActor
final class ProfileViewController: UIViewController, ProfilePresentable, ProfileViewControllable {
    weak var listener: ProfilePresentableListener?
    func update(displayName: String) async {}
}
#elseif canImport(AppKit)
import AppKit

@MainActor
final class ProfileViewController: NSViewController, ProfilePresentable, ProfileViewControllable {
    weak var listener: ProfilePresentableListener?
    func update(displayName: String) async {}
}
#endif

// snippet.show
import napkin

protocol ProfileDependency: Dependency {
    var userService: UserService { get }
}

final class ProfileComponent: Component<ProfileDependency>, @unchecked Sendable {
    // Pass-through services and locally created instances live here.
    var userService: UserService { dependency.userService }
}

protocol ProfileBuildable: Buildable {
    @MainActor func build(withListener listener: ProfileListener) async -> ProfileRouting
}

final class ProfileBuilder:
    Builder<ProfileDependency>,
    ProfileBuildable,
    @unchecked Sendable
{
    override init(dependency: ProfileDependency) {
        super.init(dependency: dependency)
    }

    @MainActor
    func build(withListener listener: ProfileListener) async -> ProfileRouting {
        let component = ProfileComponent(dependency: dependency)
        let viewController = ProfileViewController()
        let interactor = ProfileInteractor(
            presenter: viewController,
            userService: component.userService
        )
        await interactor.set(listener: listener)
        let router = ProfileRouter(interactor: interactor, viewController: viewController)
        await interactor.set(router: router)
        return router
    }
}
