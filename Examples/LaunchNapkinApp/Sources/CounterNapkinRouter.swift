//
//  CounterNapkinRouter.swift
//  napkin
//
//  Created by nonplus on 5/4/26.
//

import napkin

@MainActor
protocol CounterNapkinViewControllable: ViewControllable {
    // Declare methods the router invokes to manipulate the view hierarchy.
}

@MainActor
final class CounterNapkinRouter:
    ViewableRouter<CounterNapkinInteractor, CounterNapkinViewControllable>,
    CounterNapkinRouting
{

    override init(
        interactor: CounterNapkinInteractor,
        viewController: CounterNapkinViewControllable
    ) {
        super.init(interactor: interactor, viewController: viewController)
    }
}
