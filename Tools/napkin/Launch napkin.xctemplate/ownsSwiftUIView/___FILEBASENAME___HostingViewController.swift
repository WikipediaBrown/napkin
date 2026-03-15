//___FILEHEADER___

import napkin
import SwiftUI

protocol ___VARIABLE_productName___PresentableListener: AnyObject {
    // TODO: Declare properties and methods that the view controller can invoke to perform
    // business logic, such as signIn(). This protocol is implemented by the corresponding
    // interactor class.
}

#if canImport(UIKit)
@MainActor final class ___VARIABLE_productName___ViewController: UIHostingController<___VARIABLE_productName___View>, ___VARIABLE_productName___Presentable {

    weak var listener: ___VARIABLE_productName___PresentableListener?

    init() {
        super.init(rootView: ___VARIABLE_productName___View())
    }

    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
#elseif canImport(AppKit)
@MainActor final class ___VARIABLE_productName___ViewController: NSHostingController<___VARIABLE_productName___View>, ___VARIABLE_productName___Presentable {

    weak var listener: ___VARIABLE_productName___PresentableListener?

    init() {
        super.init(rootView: ___VARIABLE_productName___View())
    }

    @MainActor required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
#endif

extension ___VARIABLE_productName___ViewController: ___VARIABLE_productName___ViewControllable {}
