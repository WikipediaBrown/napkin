//
//  Copyright (c) 2017. Uber Technologies
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import Combine

/// A protocol for routers that own and manage a view controller.
///
/// `ViewableRouting` extends ``Routing`` to add view controller ownership.
/// Use this protocol when defining routing interfaces for napkins that have views.
///
/// ## Implementing ViewableRouting
///
/// Define a custom routing protocol that extends `ViewableRouting`:
///
/// ```swift
/// protocol MyFeatureRouting: ViewableRouting {
///     func routeToDetails()
///     func routeBackFromDetails()
/// }
/// ```
///
/// - SeeAlso: ``ViewableRouter``
/// - SeeAlso: ``Routing``
public protocol ViewableRouting: Routing {

    // The following methods must be declared in the base protocol, since `Router` internally invokes these methods.
    // In order to unit test router with a mock child router, the mocked child router first needs to conform to the
    // custom subclass routing protocol, and also this base protocol to allow the `Router` implementation to execute
    // base class logic without error.

    /// The view controller owned by this router.
    ///
    /// This property provides access to the view controller as a ``ViewControllable``,
    /// allowing the router to manage the view hierarchy.
    var viewControllable: ViewControllable { get }
}

/// A router that owns and manages a view controller.
///
/// `ViewableRouter` extends ``Router`` to add view controller ownership. Use this
/// class when your napkin has a visual representation (UIKit or SwiftUI).
///
/// ## Overview
///
/// A viewable router:
/// - Owns a strongly-typed view controller
/// - Manages the view controller's lifecycle in sync with the router
/// - Provides leak detection for the view controller
/// - Can present and dismiss child view controllers
///
/// ## Usage
///
/// ```swift
/// final class MyFeatureRouter: ViewableRouter<MyFeatureInteractor, MyFeatureViewController>,
///                              MyFeatureRouting {
///
///     private let detailsBuilder: DetailsBuildable
///     private var detailsRouter: DetailsRouting?
///
///     init(interactor: MyFeatureInteractor,
///          viewController: MyFeatureViewController,
///          detailsBuilder: DetailsBuildable) {
///         self.detailsBuilder = detailsBuilder
///         super.init(interactor: interactor, viewController: viewController)
///         interactor.router = self
///     }
///
///     func routeToDetails() {
///         guard detailsRouter == nil else { return }
///
///         let router = detailsBuilder.build(withListener: interactor)
///         detailsRouter = router
///         attachChild(router)
///
///         // Present the view controller
///         viewController.present(router.viewControllable.uiviewController, animated: true)
///     }
///
///     func routeBackFromDetails() {
///         guard let router = detailsRouter else { return }
///
///         // Dismiss the view controller
///         viewController.dismiss(animated: true)
///
///         detachChild(router)
///         detailsRouter = nil
///     }
/// }
/// ```
///
/// ## SwiftUI Integration
///
/// For SwiftUI views, use a `UIHostingController`:
///
/// ```swift
/// final class MySwiftUIRouter: ViewableRouter<MyInteractor, MyHostingController>,
///                              MyRouting {
///     // Implementation
/// }
/// ```
///
/// ## Topics
///
/// ### Creating a ViewableRouter
///
/// - ``init(interactor:viewController:)``
///
/// ### Accessing the View Controller
///
/// - ``viewController``
/// - ``viewControllable``
///
/// - SeeAlso: ``ViewableRouting``
/// - SeeAlso: ``Router``
/// - SeeAlso: ``LaunchRouter``
open class ViewableRouter<InteractorType, ViewControllerType>: Router<InteractorType>, ViewableRouting {

    /// The strongly-typed view controller owned by this router.
    ///
    /// Use this property to access view controller-specific methods and properties.
    /// For presenting or embedding in other view controllers, use ``viewControllable``.
    public let viewController: ViewControllerType

    /// The view controller as a ``ViewControllable`` protocol reference.
    ///
    /// Use this property when you need to access the underlying `UIViewController`
    /// for presentation or embedding purposes.
    public let viewControllable: ViewControllable

    /// Creates a viewable router with the specified interactor and view controller.
    ///
    /// The view controller must conform to ``ViewControllable``. If it doesn't,
    /// this initializer will trigger a fatal error.
    ///
    /// - Parameters:
    ///   - interactor: The interactor that this router will own and manage.
    ///   - viewController: The view controller that this router will own.
    /// - Precondition: The view controller must conform to ``ViewControllable``.
    public init(interactor: InteractorType, viewController: ViewControllerType) {
        self.viewController = viewController
        guard let viewControllable = viewController as? ViewControllable else {
            fatalError("\(viewController) should conform to \(ViewControllable.self)")
        }
        self.viewControllable = viewControllable

        super.init(interactor: interactor)
    }

    // MARK: - Internal

    override func internalDidLoad() {
        setupViewControllerLeakDetection()

        super.internalDidLoad()
    }

    // MARK: - Private

    private var cancellables = Set<AnyCancellable>()
    private var viewControllerDisappearExpectation: LeakDetectionHandle?

    private func setupViewControllerLeakDetection() {
        let cancellable = interactable.isActiveStream
            // Do not retain self here to guarantee execution. Retaining self will cause the dispose bag to never be
            // disposed, thus self is never deallocated. Also cannot just store the disposable and call dispose(),
            // since we want to keep the subscription alive until deallocation, in case the router is re-attached.
            // Using weak does require the router to be retained until its interactor is deactivated.
            .sink { [weak self] (isActive: Bool) in
                guard let strongSelf = self else {
                    return
                }

                strongSelf.viewControllerDisappearExpectation?.cancel()
                strongSelf.viewControllerDisappearExpectation = nil

                if !isActive {
                    let viewController = strongSelf.viewControllable.uiviewController
                    strongSelf.viewControllerDisappearExpectation = LeakDetector.instance.expectViewControllerDisappear(viewController: viewController)
                }
            }
        cancellables.insert(cancellable)
    }

    deinit {
        LeakDetector.instance.expectDeallocate(object: viewControllable.uiviewController, inTime: LeakDefaultExpectationTime.viewDisappear)
    }
}
