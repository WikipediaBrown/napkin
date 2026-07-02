import napkin
import SwiftUI

// The Presenter-subclass style (LoggedIn shows the other style: the view
// controller conforming to the presentable directly). @Observable is
// re-annotated so THIS class's stored properties are tracked; the stored
// properties are the view model.
@MainActor
@Observable
final class PitBoardNapkinPresenter: Presenter<PitBoardNapkinViewController>, PitBoardNapkinPresentable {

    var sections: [PitBoardSection] = []
    var specials: [Special] = []

    @ObservationIgnored weak var listener: PitBoardNapkinPresentableListener? {
        didSet { viewController.listener = listener }
    }

    func present(sections: [PitBoardSection]) async {
        withAnimation(.easeInOut(duration: 0.3)) {
            self.sections = sections
        }
    }

    func present(specials: [Special]) async {
        withAnimation(.easeInOut(duration: 0.3)) {
            self.specials = specials
        }
    }
}
