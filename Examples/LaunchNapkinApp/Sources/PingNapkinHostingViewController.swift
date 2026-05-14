import napkin
import SwiftUI

protocol PingNapkinPresentableListener: AnyObject, Sendable {
    func didTapSwap() async
}

#if canImport(UIKit)
@MainActor final class PingNapkinViewController: UIHostingController<PingNapkinView>, PingNapkinPresentable {

    weak var listener: PingNapkinPresentableListener? {
        didSet { rootView.listener = listener }
    }

    init() {
        super.init(rootView: PingNapkinView())
    }

    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
#elseif canImport(AppKit)
@MainActor final class PingNapkinViewController: NSHostingController<PingNapkinView>, PingNapkinPresentable {

    weak var listener: PingNapkinPresentableListener? {
        didSet { rootView.listener = listener }
    }

    init() {
        super.init(rootView: PingNapkinView())
    }

    @MainActor required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
#endif

extension PingNapkinViewController: PingNapkinViewControllable {}
