// snippet.hide
import napkin

struct User: Sendable {
    let firstName: String
    let lastName: String
}

protocol UserService: Sendable {
    var currentUser: User { get async }
}

@MainActor
protocol ProfileRouting: ViewableRouting, Sendable {
    // Methods the interactor can invoke to drive child routing.
}

protocol ProfileListener: AnyObject, Sendable {
    func profileDidFinish() async
}

protocol ProfilePresentableListener: AnyObject, Sendable {
    func didTapDone() async
}

// snippet.show
import napkin

protocol ProfilePresentable: Presentable, Sendable {
    @MainActor var listener: ProfilePresentableListener? { get set }
    func update(displayName: String) async
}

final actor ProfileInteractor: PresentableInteractable, ProfilePresentableListener {

    nonisolated let lifecycle = InteractorLifecycle()
    nonisolated let presenter: ProfilePresentable

    weak var router: ProfileRouting?
    weak var listener: ProfileListener?

    private let userService: UserService

    init(presenter: ProfilePresentable, userService: UserService) {
        self.presenter = presenter
        self.userService = userService
    }

    func set(router: ProfileRouting?) { self.router = router }
    func set(listener: ProfileListener?) { self.listener = listener }

    func didBecomeActive() async {
        let user = await userService.currentUser
        await presenter.update(displayName: "\(user.firstName) \(user.lastName)")
        await MainActor.run { presenter.listener = self }
    }

    func willResignActive() async {
        await MainActor.run { presenter.listener = nil }
    }

    // MARK: - ProfilePresentableListener

    func didTapDone() async {
        await listener?.profileDidFinish()
    }
}
