//
//  Copyright (c) 2017. Uber Technologies
//  Licensed under the Apache License, Version 2.0
//

import Foundation
import Observation

/// The base protocol for all presenters. `@MainActor`-isolated so views
/// (UIKit or SwiftUI) can read presenter state synchronously.
///
/// Feature-specific presentable protocols extend this protocol to declare
/// the methods the interactor calls. Those methods are typically `async`
/// (the interactor is an `actor`, the presenter is `@MainActor`).
@MainActor
public protocol Presentable: AnyObject {}

/// A base class for presenters. `@Observable` so SwiftUI views can read
/// stored properties of subclasses directly. UIKit views can observe via
/// `Observations { presenter.foo }` to bind to changes.
///
/// `Presenter` is optional in the napkin architecture: napkins without a view
/// use ``Interactor`` directly; napkins with a view use
/// ``PresentableInteractor`` and either subclass `Presenter` here or have the
/// view controller conform to a feature-specific `Presentable` protocol.
@MainActor
@Observable
open class Presenter<ViewControllerType: ViewControllable>: Presentable {

    /// The view controller this presenter updates.
    public let viewController: ViewControllerType

    public init(viewController: ViewControllerType) {
        self.viewController = viewController
    }
}
