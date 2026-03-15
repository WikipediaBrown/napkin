//___FILEHEADER___

import napkin

#if canImport(UIKit)
import UIKit

protocol ___VARIABLE_productName___PresentableListener: AnyObject {
    // TODO: Declare properties and methods that the view controller can invoke to perform
    // business logic, such as signIn(). This protocol is implemented by the corresponding
    // interactor class.
}

@MainActor final class ___VARIABLE_productName___ViewController: UIViewController, ___VARIABLE_productName___Presentable {

    weak var listener: ___VARIABLE_productName___PresentableListener?
}
#elseif canImport(AppKit)
import AppKit

protocol ___VARIABLE_productName___PresentableListener: AnyObject {
    // TODO: Declare properties and methods that the view controller can invoke to perform
    // business logic, such as signIn(). This protocol is implemented by the corresponding
    // interactor class.
}

@MainActor final class ___VARIABLE_productName___ViewController: NSViewController, ___VARIABLE_productName___Presentable {

    weak var listener: ___VARIABLE_productName___PresentableListener?
}
#endif

extension ___VARIABLE_productName___ViewController: ___VARIABLE_productName___ViewControllable {}