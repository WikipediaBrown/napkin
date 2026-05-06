import Testing
@testable import napkin

#if canImport(UIKit)
import UIKit

@MainActor
private protocol StubViewControllable: ViewControllable {}

private final class StubViewController: UIViewController, StubViewControllable {}

@Suite("ViewControllable")
@MainActor
struct ViewControllableTests {

    @Test func uiViewControllerSubclassGetsDefaultImplementation() {
        let vc = StubViewController()
        let viewControllable: any ViewControllable = vc
        #expect(viewControllable.uiviewController === vc)
    }
}
#endif
