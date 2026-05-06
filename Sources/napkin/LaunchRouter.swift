//
//  Copyright (c) 2017. Uber Technologies
//  Licensed under the Apache License, Version 2.0
//

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// A protocol for the root router of an application.
@MainActor
public protocol LaunchRouting: ViewableRouting {
#if canImport(UIKit)
    func launch(from window: UIWindow) async
#elseif canImport(AppKit)
    func launch(from window: NSWindow) async
#endif
}

/// The root router for a napkin-based application.
@MainActor
open class LaunchRouter<InteractorType, ViewControllerType>:
    ViewableRouter<InteractorType, ViewControllerType>, LaunchRouting {

    public override init(interactor: InteractorType, viewController: ViewControllerType) {
        super.init(interactor: interactor, viewController: viewController)
    }

#if canImport(UIKit)
    public final func launch(from window: UIWindow) async {
        window.rootViewController = viewControllable.uiviewController
        window.makeKeyAndVisible()
        await interactable.activate()
        await load()
    }
#elseif canImport(AppKit)
    public final func launch(from window: NSWindow) async {
        window.contentViewController = viewControllable.nsviewController
        window.makeKeyAndOrderFront(nil)
        await interactable.activate()
        await load()
    }
#endif
}
