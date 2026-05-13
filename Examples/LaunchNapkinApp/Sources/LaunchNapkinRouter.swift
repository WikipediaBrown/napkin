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

    private let counterBuilder: CounterNapkinBuildable
    private let quoteBuilder: QuoteNapkinBuildable
    private var counterRouter: CounterNapkinRouting?
    private var quoteRouter: QuoteNapkinRouting?

    init(
        interactor: LaunchNapkinInteractor,
        viewController: LaunchNapkinViewControllable,
        counterBuilder: CounterNapkinBuildable,
        quoteBuilder: QuoteNapkinBuildable
    ) {
        self.counterBuilder = counterBuilder
        self.quoteBuilder = quoteBuilder
        super.init(interactor: interactor, viewController: viewController)
    }

    // MARK: - LaunchNapkinRouting

    func routeToCounter() async {
        guard counterRouter == nil else { return }
        let router = await counterBuilder.build(withListener: interactor)
        counterRouter = router
        await attachChild(router)
        #if canImport(UIKit)
        viewController.uiviewController.present(
            router.viewControllable.uiviewController,
            animated: true
        )
        #endif
    }

    func routeBackFromCounter() async {
        guard let router = counterRouter else { return }
        counterRouter = nil
        #if canImport(UIKit)
        router.viewControllable.uiviewController.dismiss(animated: true)
        #endif
        await detachChild(router)
    }

    func routeToQuote() async {
        guard quoteRouter == nil else { return }
        let router = await quoteBuilder.build(withListener: interactor)
        quoteRouter = router
        await attachChild(router)
        #if canImport(UIKit)
        viewController.uiviewController.present(
            router.viewControllable.uiviewController,
            animated: true
        )
        #endif
    }

    func routeBackFromQuote() async {
        guard let router = quoteRouter else { return }
        quoteRouter = nil
        #if canImport(UIKit)
        router.viewControllable.uiviewController.dismiss(animated: true)
        #endif
        await detachChild(router)
    }
}
