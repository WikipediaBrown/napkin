//
//  Copyright (c) 2017. Uber Technologies
//  Licensed under the Apache License, Version 2.0
//

/// A protocol for routers that own and manage a view controller.
///
/// `ViewableRouting` extends ``Routing`` with a single requirement: a
/// ``viewControllable`` property that exposes the underlying platform view
/// controller. Parent routers use this property to present, push, embed, or
/// otherwise reach the child's view in the UIKit / AppKit hierarchy.
///
/// - SeeAlso: ``Routing``
/// - SeeAlso: ``ViewableRouter``
/// - SeeAlso: ``LaunchRouting``
///
/// ## Topics
///
/// ### Accessing the View
///
/// - ``viewControllable``
///
@MainActor
public protocol ViewableRouting: Routing {

    /// The view controller managed by this router, exposed as the
    /// type-erased ``ViewControllable`` protocol.
    ///
    /// ``ViewableRouter`` also exposes the concretely typed
    /// ``ViewableRouter/viewController``; reach for this protocol-level
    /// requirement when you only need to present or embed the view in the
    /// host hierarchy.
    var viewControllable: ViewControllable { get }
}

/// A router that owns a view controller.
///
/// `@MainActor`-isolated. Subclass `ViewableRouter` for napkins that have a
/// view of their own; for headless napkins, subclass ``Router`` directly.
///
/// ## Overview
///
/// `ViewableRouter` keeps two references to the same view controller
/// instance:
///
/// - ``viewController`` is concretely typed (`ViewControllerType`) so
///   subclasses can call feature-specific `Presentable` methods on it
///   directly.
/// - ``viewControllable`` is the type-erased ``ViewControllable`` view used
///   by parent routers to embed or present the underlying
///   `UIViewController` / `NSViewController`.
///
/// Both are populated in the initializer; the `ViewControllable`
/// conformance is enforced at runtime via a `fatalError` if missing.
///
/// ## Usage
///
/// **UIKit:**
///
/// ```swift
/// final class HomeViewController: UIViewController, HomeViewControllable, HomePresentable {
///     // Conforms to ViewControllable automatically via the UIKit extension.
/// }
///
/// @MainActor
/// final class HomeRouter: ViewableRouter<HomeInteractor, HomeViewController>, HomeRouting {
///
///     init(
///         interactor: HomeInteractor,
///         viewController: HomeViewController,
///         profileBuilder: ProfileBuildable
///     ) {
///         self.profileBuilder = profileBuilder
///         super.init(interactor: interactor, viewController: viewController)
///     }
///
///     func routeToProfile() async {
///         let r = await profileBuilder.build(withListener: interactor)
///         await attachChild(r)
///         viewController.present(r.viewControllable.uiviewController, animated: true)
///     }
///
///     private let profileBuilder: ProfileBuildable
/// }
/// ```
///
/// **SwiftUI (via `UIHostingController`):**
///
/// ```swift
/// final class HomeHostingController: UIHostingController<HomeView>, HomeViewControllable {
///     init(presenter: HomePresenter, listener: HomeViewListener) {
///         super.init(rootView: HomeView(presenter: presenter, listener: listener))
///     }
///     required init?(coder: NSCoder) { fatalError() }
/// }
///
/// @MainActor
/// final class HomeRouter: ViewableRouter<HomeInteractor, HomeHostingController>, HomeRouting {
///     // Same shape as the UIKit example.
/// }
/// ```
///
/// - SeeAlso: ``ViewableRouting``
/// - SeeAlso: ``Router``
/// - SeeAlso: ``ViewControllable``
///
/// ## Topics
///
/// ### Creating a ViewableRouter
///
/// - ``init(interactor:viewController:)``
///
/// ### Accessing the View
///
/// - ``viewController``
/// - ``viewControllable``
///
@MainActor
open class ViewableRouter<InteractorType, ViewControllerType>:
    Router<InteractorType>, ViewableRouting {

    /// The concretely typed view controller managed by this router.
    ///
    /// Use this property to call feature-specific methods on the view
    /// controller — for example, presenting child view controllers or
    /// reading state from the SwiftUI hosting view.
    public var viewController: ViewControllerType { _viewController }

    /// The view controller as the type-erased ``ViewControllable``.
    ///
    /// This is the same instance as ``viewController``; the cast is
    /// performed once in ``init(interactor:viewController:)``.
    public var viewControllable: ViewControllable { _viewControllable }

    /// Creates a router that pairs an interactor with a view controller.
    ///
    /// - Parameters:
    ///   - interactor: The router's interactor. Must conform to
    ///     ``Interactable``.
    ///   - viewController: The view controller managed by this router. Must
    ///     conform to ``ViewControllable``; the initializer traps if it
    ///     does not.
    /// - Precondition: `viewController` conforms to ``ViewControllable``.
    /// - Precondition: `interactor` conforms to ``Interactable``.
    public init(interactor: InteractorType, viewController: ViewControllerType) {
        self._viewController = viewController
        guard let viewControllable = viewController as? ViewControllable else {
            fatalError("\(viewController) should conform to \(ViewControllable.self)")
        }
        self._viewControllable = viewControllable
        super.init(interactor: interactor)
    }

    // MARK: - Private

    private let _viewController: ViewControllerType
    private let _viewControllable: ViewControllable
}
