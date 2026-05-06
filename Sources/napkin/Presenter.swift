//
//  Copyright (c) 2017. Uber Technologies
//  Licensed under the Apache License, Version 2.0
//

import Foundation
import Observation

/// The base protocol for all presenters.
///
/// `Presentable` is `@MainActor`-isolated so views — UIKit `UIViewController`s
/// or SwiftUI `View`s — can read presenter state synchronously, without
/// hopping isolation domains.
///
/// ## Overview
///
/// Feature-specific `Presentable` protocols extend this protocol to declare
/// the methods that the interactor calls on the presenter. Those methods are
/// typically `async`: the interactor is an `actor`, the presenter is
/// `@MainActor`, and crossing isolation domains requires `await`.
///
/// You have two options for who conforms to a feature-specific `Presentable`:
///
/// - A dedicated ``Presenter`` subclass (recommended when there is non-trivial
///   view-state to hold). The view controller observes the presenter via
///   `@Bindable` (SwiftUI) or `Observations { ... }` (UIKit) and stays a
///   thin renderer.
/// - The view controller itself, when there is no separate state to hold and
///   the presenter would just delegate every method to the view controller
///   anyway.
///
/// Both styles compose with ``PresentableInteractable`` — only the conforming
/// type changes.
///
/// ## Usage
///
/// ```swift
/// protocol HomePresentable: Presentable {
///     func presentUser(_ user: User) async
///     func presentLogoutFailure(_ message: String) async
/// }
/// ```
///
/// - SeeAlso: ``Presenter``
/// - SeeAlso: ``PresentableInteractable``
/// - SeeAlso: ``ViewControllable``
@MainActor
public protocol Presentable: AnyObject {}

/// A base class for presenters with `@Observable` view state.
///
/// `Presenter` is `@MainActor`-isolated and `@Observable`, so SwiftUI views
/// can read its stored properties directly via `@Bindable` and UIKit views
/// can observe them via the `Observations { ... }` macro.
///
/// ## Overview
///
/// `Presenter` is optional in the napkin architecture. There are three
/// shapes a feature commonly takes:
///
/// - **Headless napkin (no view).** Conform to ``Interactable`` directly;
///   no presenter at all.
/// - **Viewful napkin with a presenter object.** Subclass `Presenter`,
///   add `@Observable`-friendly stored properties, and have it conform to
///   the feature's `Presentable` protocol. The view controller renders
///   from the presenter and forwards user events to a listener.
/// - **Viewful napkin without a separate presenter.** Have the view
///   controller conform to the feature's `Presentable` protocol directly,
///   and skip `Presenter`.
///
/// `Presenter` is the right choice when you have view state worth
/// formatting once and reading from multiple places — display strings,
/// loading flags, computed labels — and you want to keep the view layer
/// thin.
///
/// ## Usage
///
/// **Define the presentable seam:**
///
/// ```swift
/// protocol HomePresentable: Presentable {
///     func presentUser(_ user: User) async
/// }
/// ```
///
/// **Implement it as a `Presenter` subclass:**
///
/// ```swift
/// @MainActor
/// final class HomePresenter: Presenter<HomeViewController>, HomePresentable {
///
///     var displayName: String = ""
///     var isLoggingOut: Bool = false
///
///     func presentUser(_ user: User) async {
///         displayName = "\(user.firstName) \(user.lastName)"
///     }
/// }
/// ```
///
/// **Read it from SwiftUI:**
///
/// ```swift
/// struct HomeView: View {
///     @Bindable var presenter: HomePresenter
///     let listener: HomeViewListener
///
///     var body: some View {
///         VStack {
///             Text(presenter.displayName)
///             Button("Logout") {
///                 dispatch { await listener.didTapLogout() }
///             }
///         }
///     }
/// }
/// ```
///
/// **Read it from UIKit:**
///
/// ```swift
/// final class HomeViewController: UIViewController, HomeViewControllable {
///     var presenter: HomePresenter!
///
///     override func viewDidLoad() {
///         super.viewDidLoad()
///         Observations {
///             nameLabel.text = presenter.displayName
///         }
///     }
/// }
/// ```
///
/// ## Topics
///
/// ### Creating a Presenter
///
/// - ``init(viewController:)``
///
/// ### Accessing the View
///
/// - ``viewController``
///
/// - SeeAlso: ``Presentable``
/// - SeeAlso: ``ViewControllable``
@MainActor
@Observable
open class Presenter<ViewControllerType: ViewControllable>: Presentable {

    /// The view controller this presenter updates.
    ///
    /// Stored for the rare case that the presenter needs to call directly
    /// into the view controller (for example, to push a UIKit view
    /// controller onto a navigation stack). In typical SwiftUI usage the
    /// presenter only mutates `@Observable` state and the view controller
    /// holds the presenter instead — this property is rarely read.
    public let viewController: ViewControllerType

    /// Creates a presenter bound to the given view controller.
    ///
    /// - Parameter viewController: The view controller this presenter will
    ///   update. Must conform to ``ViewControllable``.
    public init(viewController: ViewControllerType) {
        self.viewController = viewController
    }
}
