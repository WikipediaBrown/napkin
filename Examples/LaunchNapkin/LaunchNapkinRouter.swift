//
//  LaunchNapkinRouter.swift
//  napkin
//
//  Created by nonplus on 3/13/26.
//

import napkin

@MainActor protocol LaunchNapkinInteractable: Interactable {
    var router: LaunchNapkinRouting? { get set }
    var listener: LaunchNapkinListener? { get set }
}

@MainActor protocol LaunchNapkinViewControllable: ViewControllable {
    // TODO: Declare methods the router invokes to manipulate the view hierarchy.
}

@MainActor final class LaunchNapkinRouter: LaunchRouter<LaunchNapkinInteractable, LaunchNapkinViewControllable>, LaunchNapkinRouting {

    // TODO: Constructor inject child builder protocols to allow building children.
    init(interactor: LaunchNapkinInteractable, viewController: LaunchNapkinViewControllable) {
        super.init(interactor: interactor, viewController: viewController)
        interactor.router = self
    }
}
