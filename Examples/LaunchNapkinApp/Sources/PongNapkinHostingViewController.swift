import napkin
import SwiftUI

protocol PongNapkinPresentableListener: AnyObject, Sendable {
    func didTapSwap() async
}

#if canImport(UIKit)
@MainActor final class PongNapkinViewController: UIHostingController<PongNapkinView>, PongNapkinPresentable {

    weak var listener: PongNapkinPresentableListener? {
        didSet { rootView.listener = listener }
    }

    init() {
        super.init(rootView: PongNapkinView())
    }

    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(connectedCount: Int?) async {
        rootView.connectedCount = connectedCount
    }
}
#elseif canImport(AppKit)
@MainActor final class PongNapkinViewController: NSHostingController<PongNapkinView>, PongNapkinPresentable {

    weak var listener: PongNapkinPresentableListener? {
        didSet { rootView.listener = listener }
    }

    init() {
        super.init(rootView: PongNapkinView())
    }

    @MainActor required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(connectedCount: Int?) async {
        rootView.connectedCount = connectedCount
    }
}
#endif

extension PongNapkinViewController: PongNapkinViewControllable {}
