import Testing
@testable import napkin

#if canImport(UIKit)
import UIKit

@Suite("ViewControllable")
@MainActor
struct ViewControllableTests {

    @Test func uiViewControllerSubclassConformsAutomatically() {
        let vc = UIViewController() as ViewControllable
        #expect(vc.uiviewController is UIViewController)
    }
}
#endif
