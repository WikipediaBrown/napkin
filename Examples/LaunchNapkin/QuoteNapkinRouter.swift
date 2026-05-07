//
//  QuoteNapkinRouter.swift
//  napkin
//
//  Created by nonplus on 5/4/26.
//

import napkin

@MainActor
protocol QuoteNapkinViewControllable: ViewControllable {
    // Declare methods the router invokes to manipulate the view hierarchy.
}

@MainActor
final class QuoteNapkinRouter:
    ViewableRouter<QuoteNapkinInteractor, QuoteNapkinViewControllable>,
    QuoteNapkinRouting
{

    override init(
        interactor: QuoteNapkinInteractor,
        viewController: QuoteNapkinViewControllable
    ) {
        super.init(interactor: interactor, viewController: viewController)
    }
}
