import napkin
import SwiftUI

protocol LoggedOutNapkinPresentableListener: AnyObject, Sendable {
    func didTapLogin() async
}

#if canImport(UIKit)
@MainActor final class LoggedOutNapkinViewController: UIHostingController<LoggedOutNapkinView>, LoggedOutNapkinPresentable {

    weak var listener: LoggedOutNapkinPresentableListener? {
        didSet { rootView.listener = listener }
    }

    init() {
        super.init(rootView: LoggedOutNapkinView())
    }

    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
#elseif canImport(AppKit)
@MainActor final class LoggedOutNapkinViewController: NSHostingController<LoggedOutNapkinView>, LoggedOutNapkinPresentable {

    weak var listener: LoggedOutNapkinPresentableListener? {
        didSet { rootView.listener = listener }
    }

    init() {
        super.init(rootView: LoggedOutNapkinView())
    }

    @MainActor required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
#endif

extension LoggedOutNapkinViewController: LoggedOutNapkinViewControllable {}
