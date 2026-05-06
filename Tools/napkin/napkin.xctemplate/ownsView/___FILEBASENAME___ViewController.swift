//___FILEHEADER___

import napkin

#if canImport(UIKit)
import UIKit

protocol ___VARIABLE_productName___PresentableListener: AnyObject, Sendable {
    // TODO: Declare properties and methods that the view controller can invoke to perform
    // business logic, such as signIn(). This protocol is implemented by the corresponding
    // interactor actor; methods are async.
}

@MainActor final class ___VARIABLE_productName___ViewController: UIViewController, ___VARIABLE_productName___Presentable {

    weak var listener: ___VARIABLE_productName___PresentableListener?

    override func viewDidLoad() {
        super.viewDidLoad()
        // TODO: Configure the view. Forward user events to the listener with `dispatch`:
        //   dispatch { [listener] in await listener?.didTapSomething() }
    }
}
#elseif canImport(AppKit)
import AppKit

protocol ___VARIABLE_productName___PresentableListener: AnyObject, Sendable {
    // TODO: Declare properties and methods that the view controller can invoke to perform
    // business logic, such as signIn(). This protocol is implemented by the corresponding
    // interactor actor; methods are async.
}

@MainActor final class ___VARIABLE_productName___ViewController: NSViewController, ___VARIABLE_productName___Presentable {

    weak var listener: ___VARIABLE_productName___PresentableListener?

    override func viewDidLoad() {
        super.viewDidLoad()
        // TODO: Configure the view. Forward user events to the listener with `dispatch`.
    }
}
#endif

extension ___VARIABLE_productName___ViewController: ___VARIABLE_productName___ViewControllable {}
