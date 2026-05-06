//___FILEHEADER___

import napkin

@MainActor
protocol ___VARIABLE_productName___ViewControllable: ViewControllable {
    // TODO: Declare methods the router invokes to manipulate the view hierarchy.
}

@MainActor
final class ___VARIABLE_productName___Router:
    LaunchRouter<___VARIABLE_productName___Interactor, ___VARIABLE_productName___ViewControllable>,
    ___VARIABLE_productName___Routing
{

    // TODO: Constructor inject child builder protocols to allow building children.
    override init(interactor: ___VARIABLE_productName___Interactor, viewController: ___VARIABLE_productName___ViewControllable) {
        super.init(interactor: interactor, viewController: viewController)
    }
}
