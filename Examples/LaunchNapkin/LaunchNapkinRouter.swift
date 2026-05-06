//
//  LaunchNapkinRouter.swift
//  napkin
//
//  Created by nonplus on 3/13/26.
//

import napkin

@MainActor
protocol LaunchNapkinViewControllable: ViewControllable {
    // Declare methods the router invokes to manipulate the view hierarchy.
}

@MainActor
final class LaunchNapkinRouter:
    LaunchRouter<LaunchNapkinInteractor, LaunchNapkinViewControllable>,
    LaunchNapkinRouting
{

    // Constructor inject child builder protocols to allow building children.
    override init(interactor: LaunchNapkinInteractor, viewController: LaunchNapkinViewControllable) {
        super.init(interactor: interactor, viewController: viewController)
    }
}
