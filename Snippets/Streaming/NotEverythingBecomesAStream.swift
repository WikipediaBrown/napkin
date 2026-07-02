// snippet.hide
//
// Compiled mirror of README.md § "Streaming State Down the Tree" —
// "Not everything becomes a stream" (KVO publisher replacement).
// UIKit-only by nature; compiles to nothing on macOS.
//
import napkin

#if canImport(UIKit)
import UIKit

protocol ProfilePresentableListener: AnyObject, Sendable {
    func didDismiss() async
}
// snippet.show
final class ProfileViewController: UIViewController {

    weak var listener: ProfilePresentableListener?

    // 0.x observed UIKit with Combine's KVO publisher:
    //
    //     publisher(for: \.parent)
    //         .sink { [weak self] parent in
    //             if parent == nil { self?.listener?.onDismiss() }
    //         }
    //         .store(in: &cancellables)
    //
    // 2.x uses the UIKit callback that KVO was wrapping:
    override func didMove(toParent parent: UIViewController?) {
        super.didMove(toParent: parent)
        if parent == nil {
            dispatch { [listener] in await listener?.didDismiss() }
        }
    }
}
// snippet.hide
#endif
