import Testing
import Observation
@testable import napkin

#if canImport(UIKit)
import UIKit

@Suite("Presenter")
@MainActor
struct PresenterTests {

    @Test func holdsViewController() {
        let vc = StubViewController()
        let presenter = StubPresenter(viewController: vc)
        #expect(presenter.viewController === vc)
    }
}

private final class StubViewController: UIViewController, ViewControllable {}

@MainActor
private final class StubPresenter: napkin.Presenter<StubViewController> {
    var title: String = ""
}
#endif
