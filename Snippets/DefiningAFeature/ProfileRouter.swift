// snippet.hide
import napkin

protocol ProfilePresentableListener: AnyObject, Sendable {
    func didTapDone() async
}

protocol ProfilePresentable: Presentable, Sendable {
    @MainActor var listener: ProfilePresentableListener? { get set }
    func update(displayName: String) async
}

protocol ProfileListener: AnyObject, Sendable {
    func profileDidFinish() async
}

final actor ProfileInteractor: PresentableInteractable, ProfilePresentableListener {
    nonisolated let lifecycle = InteractorLifecycle()
    nonisolated let presenter: ProfilePresentable

    init(presenter: ProfilePresentable) { self.presenter = presenter }
    func didTapDone() async {}
}

// snippet.show
import napkin

@MainActor
protocol ProfileViewControllable: ViewControllable {
    // Methods the router invokes on the view, e.g. presenting child VCs.
}

@MainActor
protocol ProfileRouting: ViewableRouting, Sendable {
    // Methods the interactor can invoke to drive child routing.
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
