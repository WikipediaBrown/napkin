//___FILEHEADER___

import Testing
@testable import ___PROJECTNAME___

@Suite("___VARIABLE_productName___Router")
@MainActor
struct ___VARIABLE_productName___RouterTests {

    // TODO: Declare mocks for the interactor, view controller, and child builders.

    @Test func loadCallsDidLoad() async {
        // Example: build the router and assert that calling `load()` triggers any
        // permanent child attachment performed in `didLoad()`.
        //
        //   let interactor = ___VARIABLE_productName___Interactor(presenter: presenter)
        //   let viewController = ___VARIABLE_productName___ViewControllableMock()
        //   let router = ___VARIABLE_productName___Router(interactor: interactor, viewController: viewController)
        //   await router.load()
        //   #expect(router.children.isEmpty == false)
    }

    @Test func attachChild_activatesChildInteractor() async {
        // Example:
        //   let router = makeRouter()
        //   let child = ChildRouterMock()
        //   await router.attachChild(child)
        //   #expect(child.attachCount == 1)
    }

    // MARK: - Tests
    //
    // Test that the router:
    //   - Builds and attaches the correct child napkin in response to interactor calls
    //   - Detaches and cleans up child napkins
    //   - Manipulates the view hierarchy on the view controller
}
