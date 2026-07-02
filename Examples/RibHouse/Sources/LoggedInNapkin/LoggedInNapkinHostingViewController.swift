import napkin
import SwiftUI

protocol LoggedInNapkinPresentableListener: AnyObject, Sendable {
    func didTapLogout() async
    func didTapPitBoard() async
}

#if canImport(UIKit)
@MainActor final class LoggedInNapkinViewController: UIHostingController<LoggedInNapkinView>, LoggedInNapkinPresentable {

    weak var listener: LoggedInNapkinPresentableListener? {
        didSet { rootView.listener = listener }
    }

    func present(pitSummary: String) async {
        rootView.pitSummary = pitSummary
    }

    func present(banner: String?) async {
        withAnimation(.easeInOut(duration: 0.25)) {
            rootView.banner = banner
        }
    }

    init(user: User) {
        super.init(rootView: LoggedInNapkinView(user: user))
    }

    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
#elseif canImport(AppKit)
@MainActor final class LoggedInNapkinViewController: NSHostingController<LoggedInNapkinView>, LoggedInNapkinPresentable {

    weak var listener: LoggedInNapkinPresentableListener? {
        didSet { rootView.listener = listener }
    }

    func present(pitSummary: String) async {
        rootView.pitSummary = pitSummary
    }

    func present(banner: String?) async {
        withAnimation(.easeInOut(duration: 0.25)) {
            rootView.banner = banner
        }
    }

    init(user: User) {
        super.init(rootView: LoggedInNapkinView(user: user))
    }

    @MainActor required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
#endif
