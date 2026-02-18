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

import Foundation
import Combine

/// A protocol that defines the active state scope of an interactor.
///
/// `InteractorScope` provides properties for checking and observing the active state
/// of an interactor. Use this protocol when you need to observe lifecycle changes
/// without access to the full ``Interactable`` interface.
///
/// - SeeAlso: ``Interactable``
/// - SeeAlso: ``Interactor``
public protocol InteractorScope: AnyObject {

    // The following properties must be declared in the base protocol, since `Router` internally invokes these methods.
    // In order to unit test router with a mock interactor, the mocked interactor first needs to conform to the custom
    // subclass interactor protocol, and also this base protocol to allow the `Router` implementation to execute base
    // class logic without error.

    /// A Boolean value indicating whether the interactor is currently active.
    ///
    /// An interactor is active when its parent router is attached to the router tree.
    /// Business logic should only execute when this value is `true`.
    var isActive: Bool { get }

    /// A publisher that emits the current active state and subsequent changes.
    ///
    /// This publisher uses `CurrentValueSubject` behavior, meaning new subscribers
    /// immediately receive the current active state. The publisher completes when
    /// the interactor is deallocated.
    ///
    /// ```swift
    /// interactor.isActiveStream
    ///     .filter { $0 }  // Only when active
    ///     .sink { _ in
    ///         print("Interactor became active")
    ///     }
    ///     .store(in: &cancellables)
    /// ```
    var isActiveStream: AnyPublisher<Bool, Never> { get }
}

/// The base protocol for all interactors in the napkin architecture.
///
/// `Interactable` extends ``InteractorScope`` to add lifecycle management methods.
/// The ``Router`` uses this protocol to activate and deactivate interactors as
/// they are attached and detached from the router tree.
///
/// ## Implementing Custom Interactor Protocols
///
/// Define a custom protocol that extends `Interactable` for your feature:
///
/// ```swift
/// protocol MyFeatureInteractable: Interactable {
///     var router: MyFeatureRouting? { get set }
///     var listener: MyFeatureListener? { get set }
/// }
/// ```
///
/// - Important: The ``activate()`` and ``deactivate()`` methods are called by the
///   framework. Application code should never call these methods directly.
///
/// - SeeAlso: ``Interactor``
/// - SeeAlso: ``InteractorScope``
public protocol Interactable: InteractorScope {

    // The following methods must be declared in the base protocol, since `Router` internally invokes these methods.
    // In order to unit test router with a mock interactor, the mocked interactor first needs to conform to the custom
    // subclass interactor protocol, and also this base protocol to allow the `Router` implementation to execute base
    // class logic without error.

    /// Activates the interactor.
    ///
    /// This method is called by the router when it is attached to its parent.
    /// It triggers the ``Interactor/didBecomeActive()`` callback.
    ///
    /// - Important: Do not call this method directly. The framework manages activation.
    func activate()

    /// Deactivates the interactor.
    ///
    /// This method is called by the router when it is detached from its parent.
    /// It triggers the ``Interactor/willResignActive()`` callback.
    ///
    /// - Important: Do not call this method directly. The framework manages deactivation.
    func deactivate()
}

/// The base class for all interactors in the napkin architecture.
///
/// An `Interactor` contains the business logic for a napkin unit. It has a lifecycle
/// driven by its owning ``Router``: when the router is attached, the interactor becomes
/// active; when detached, it becomes inactive.
///
/// ## Overview
///
/// The interactor is responsible for:
/// - Containing all business logic for a feature
/// - Managing subscriptions to data streams
/// - Responding to user actions (via presenter or view)
/// - Communicating with parent napkins via listener protocols
/// - Requesting navigation changes via the router
///
/// ## Lifecycle
///
/// Override these methods to respond to lifecycle changes:
/// - ``didBecomeActive()``: Called when the interactor is activated
/// - ``willResignActive()``: Called when the interactor is about to deactivate
///
/// ## Usage
///
/// ```swift
/// protocol MyFeatureListener: AnyObject {
///     func didFinishMyFeature(with result: String)
/// }
///
/// final class MyFeatureInteractor: Interactor, MyFeatureInteractable {
///
///     weak var router: MyFeatureRouting?
///     weak var listener: MyFeatureListener?
///
///     private let service: MyServiceProtocol
///     private var cancellables = Set<AnyCancellable>()
///
///     init(service: MyServiceProtocol) {
///         self.service = service
///         super.init()
///     }
///
///     override func didBecomeActive() {
///         super.didBecomeActive()
///         // Setup subscriptions
///         service.dataPublisher
///             .sink { [weak self] data in
///                 self?.handleData(data)
///             }
///             .store(in: &cancellables)
///     }
///
///     override func willResignActive() {
///         super.willResignActive()
///         // Cleanup
///         cancellables.removeAll()
///     }
///
///     func userDidTapDone() {
///         listener?.didFinishMyFeature(with: "completed")
///     }
/// }
/// ```
///
/// ## Topics
///
/// ### Lifecycle
///
/// - ``didBecomeActive()``
/// - ``willResignActive()``
/// - ``isActive``
/// - ``isActiveStream``
///
/// ### Initialization
///
/// - ``init()``
///
/// - SeeAlso: ``Interactable``
/// - SeeAlso: ``PresentableInteractor``
/// - SeeAlso: ``Router``
open class Interactor: Interactable {

    /// A Boolean value indicating whether the interactor is currently active.
    ///
    /// Check this property before performing business logic to ensure the interactor
    /// is in the correct state. This property returns `true` after ``didBecomeActive()``
    /// is called and `false` after ``willResignActive()`` completes.
    public final var isActive: Bool {
        return isActiveSubject.value
    }

    /// A publisher that emits the current and future active states.
    ///
    /// Subscribe to this publisher to react to lifecycle changes. New subscriptions
    /// immediately receive the current state.
    public final var isActiveStream: AnyPublisher<Bool, Never> {
        return isActiveSubject.eraseToAnyPublisher()
    }

    /// Creates a new interactor.
    ///
    /// Override this initializer to inject dependencies:
    ///
    /// ```swift
    /// init(service: MyServiceProtocol) {
    ///     self.service = service
    ///     super.init()
    /// }
    /// ```
    public init() {
        // No-op
    }

    /// Activates the interactor.
    ///
    /// This method is called internally by the router when attached.
    /// It sets ``isActive`` to `true` and calls ``didBecomeActive()``.
    ///
    /// - Important: Do not call this method directly.
    public final func activate() {
        guard !isActive else {
            return
        }

        isActiveSubject.send(true)

        didBecomeActive()
    }

    /// Called when the interactor becomes active.
    ///
    /// Override this method to:
    /// - Set up Combine subscriptions
    /// - Start observing data sources
    /// - Initialize state that depends on being active
    ///
    /// Always call `super.didBecomeActive()` when overriding.
    ///
    /// ```swift
    /// override func didBecomeActive() {
    ///     super.didBecomeActive()
    ///     service.fetchData()
    ///         .sink { [weak self] data in
    ///             self?.process(data)
    ///         }
    ///         .store(in: &cancellables)
    /// }
    /// ```
    open func didBecomeActive() {
        // No-op
    }

    /// Deactivates the interactor.
    ///
    /// This method is called internally by the router when detached.
    /// It calls ``willResignActive()`` and then sets ``isActive`` to `false`.
    ///
    /// - Important: Do not call this method directly.
    public final func deactivate() {
        guard isActive else {
            return
        }

        willResignActive()

        isActiveSubject.send(false)
    }

    /// Called when the interactor is about to become inactive.
    ///
    /// Override this method to:
    /// - Cancel Combine subscriptions
    /// - Release resources
    /// - Save state if needed
    ///
    /// Always call `super.willResignActive()` when overriding.
    ///
    /// ```swift
    /// override func willResignActive() {
    ///     super.willResignActive()
    ///     cancellables.removeAll()
    /// }
    /// ```
    open func willResignActive() {
        // No-op
    }

    // MARK: - Private

    private let isActiveSubject = CurrentValueSubject<Bool, Never>(false)

    deinit {
        if isActive {
            deactivate()
        }
        isActiveSubject.send(completion: .finished)
    }
}

