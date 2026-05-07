// snippet.hide
import napkin
import SwiftUI

#if canImport(UIKit)
struct ProfileView: View {
    var displayName: String = ""
    weak var listener: ProfilePresentableListener?
    var body: some View { Text(displayName) }
}

@MainActor
protocol ProfileViewControllable: ViewControllable {
    // Methods the router invokes on the view, e.g. presenting child VCs.
}
#endif

// snippet.show
import napkin
import SwiftUI

protocol ProfilePresentableListener: AnyObject, Sendable {
    func didTapDone() async
}

#if canImport(UIKit)
@MainActor
final class ProfileViewController:
    UIHostingController<ProfileView>,
    ProfilePresentable
{
    weak var listener: ProfilePresentableListener? {
        didSet { rootView.listener = listener }
    }

    init() {
        super.init(rootView: ProfileView())
    }

    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(displayName: String) async {
        rootView.displayName = displayName
    }
}
#endif

#if canImport(UIKit)
extension ProfileViewController: ProfileViewControllable {}
#endif

// snippet.hide
protocol ProfilePresentable: Presentable, Sendable {
    @MainActor var listener: ProfilePresentableListener? { get set }
    func update(displayName: String) async
}
