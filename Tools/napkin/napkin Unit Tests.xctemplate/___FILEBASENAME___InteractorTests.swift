//___FILEHEADER___

import Testing
@testable import ___PROJECTNAME___

@Suite("___VARIABLE_productName___Interactor")
struct ___VARIABLE_productName___InteractorTests {

    // TODO: Declare mocks for the router, presenter, listener, and any services.

    @Test func activate_makesInteractorActive() async {
        // Example: build the interactor with mock collaborators, activate, and assert
        // it transitioned to the active state and invoked the expected setup work.
        //
        //   let presenter = ___VARIABLE_productName___PresentableMock()
        //   let interactor = ___VARIABLE_productName___Interactor(presenter: presenter)
        //   await interactor.activate()
        //   #expect(await interactor.isActive == true)
    }

    @Test func deactivate_makesInteractorInactive() async {
        // Example:
        //   let presenter = ___VARIABLE_productName___PresentableMock()
        //   let interactor = ___VARIABLE_productName___Interactor(presenter: presenter)
        //   await interactor.activate()
        //   await interactor.deactivate()
        //   #expect(await interactor.isActive == false)
    }

    // MARK: - Tests
    //
    // Test that the interactor:
    //   - Invokes the listener for cross-napkin communication
    //   - Drives the router to attach/detach children
    //   - Calls the presenter to update the view
    //   - Cancels lifecycle-bound tasks on deactivate
}
