import napkin
import SwiftUI

protocol PitBoardNapkinPresentableListener: AnyObject, Sendable {
    func didDismiss() async
}

#if canImport(UIKit)
@MainActor final class PitBoardNapkinViewController: UIHostingController<PitBoardNapkinView> {

    weak var listener: PitBoardNapkinPresentableListener? {
        didSet { rootView.listener = listener }
    }

    init() {
        super.init(rootView: PitBoardNapkinView())
        title = "The Pit"
    }

    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Two-phase bind: the builder constructs this VC first, then the
    /// presenter (which needs the VC), then hands the presenter back so
    /// the view can read its @Observable state. This is the acyclic
    /// construction order the napkin README documents.
    func bind(presenter: PitBoardNapkinPresenter) {
        rootView.presenter = presenter
    }

    // 0.x observed this with Combine's KVO publisher
    // (`publisher(for: \.parent)`); 2.x uses the UIKit callback that KVO
    // was wrapping. Fires when the back button pops us: close the logical
    // tree to match the visual one.
    override func didMove(toParent parent: UIViewController?) {
        super.didMove(toParent: parent)
        if parent == nil {
            dispatch { [listener] in await listener?.didDismiss() }
        }
    }
}

extension PitBoardNapkinViewController: PitBoardNapkinViewControllable {}
#endif
