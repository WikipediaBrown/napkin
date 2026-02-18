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

/// The lifecycle stages of a router scope.
///
/// Use this enum to observe when a router transitions through its lifecycle stages
/// via the ``RouterScope/lifecycle`` publisher.
public enum RouterLifecycle {

    /// The router has finished loading and is ready to be used.
    ///
    /// This event is emitted once when the router's ``Router/load()`` method completes.
    /// At this point, the router's ``Router/didLoad()`` method has been called and
    /// any initial child routers should be attached.
    case didLoad
}

/// A protocol that defines the lifecycle scope of a router.
///
/// `RouterScope` provides a reactive interface for observing router lifecycle events.
/// Use the ``lifecycle`` publisher to respond to lifecycle changes.
///
/// - SeeAlso: ``RouterLifecycle``
/// - SeeAlso: ``Routing``
public protocol RouterScope: AnyObject {

    /// A publisher that emits lifecycle events for this router.
    ///
    /// Subscribe to this publisher to observe when the router reaches specific lifecycle stages.
    /// The publisher completes when the router is deallocated.
    ///
    /// ```swift
    /// router.lifecycle
    ///     .sink { stage in
    ///         switch stage {
    ///         case .didLoad:
    ///             print("Router loaded")
    ///         }
    ///     }
    ///     .store(in: &cancellables)
    /// ```
    var lifecycle: AnyPublisher<RouterLifecycle, Never> { get }
}

/// The base protocol for all routers in the napkin architecture.
///
/// `Routing` extends ``RouterScope`` to provide the core functionality for managing
/// the napkin tree structure. Routers are responsible for:
/// - Owning and driving the lifecycle of their associated ``Interactor``
/// - Managing child routers through attach and detach operations
/// - Coordinating navigation within the application
///
/// ## Overview
///
/// A router acts as the backbone of a napkin unit, connecting business logic (interactor)
/// with navigation and child management. The router tree mirrors the logical structure
/// of your application.
///
/// ## Implementing Custom Routing Protocols
///
/// Define a custom routing protocol that extends `Routing` for type-safe navigation:
///
/// ```swift
/// protocol MyFeatureRouting: Routing {
///     func routeToDetails(withId id: String)
///     func routeBackFromDetails()
/// }
/// ```
///
/// - Note: The attach and detach methods accept `Routing` rather than concrete `Router`
///   instances to support mocking in unit tests.
///
/// - SeeAlso: ``Router``
/// - SeeAlso: ``Interactable``
public protocol Routing: RouterScope {

    // The following methods must be declared in the base protocol, since `Router` internally  invokes these methods.
    // In order to unit test router with a mock child router, the mocked child router first needs to conform to the
    // custom subclass routing protocol, and also this base protocol to allow the `Router` implementation to execute
    // base class logic without error.

    /// The interactor associated with this router.
    ///
    /// The router owns this interactor and drives its lifecycle. When the router is attached
    /// to a parent, the interactor is activated. When detached, the interactor is deactivated.
    var interactable: Interactable { get }

    /// The list of child routers currently attached to this router.
    ///
    /// This array contains all routers that have been attached via ``attachChild(_:)``
    /// and not yet detached. The order reflects the order of attachment.
    var children: [Routing] { get }

    /// Loads the router and prepares it for use.
    ///
    /// This method is called internally by the framework when the router is attached
    /// to its parent. It triggers the ``Router/didLoad()`` callback.
    ///
    /// - Important: Application code should never invoke this method directly.
    ///   The framework manages router loading automatically.
    func load()

    // We cannot declare the attach/detach child methods to take in concrete `Router` instances,
    // since during unit testing, we need to use mocked child routers.

    /// Attaches a child router to this router.
    ///
    /// When a child router is attached:
    /// 1. The child's interactor is activated
    /// 2. The child router is loaded (if not already loaded)
    /// 3. The child is added to the ``children`` array
    ///
    /// - Parameter child: The child router to attach. Must not already be attached.
    /// - Precondition: The child router must not already be attached to this router.
    func attachChild(_ child: Routing)

    /// Detaches a child router from this router.
    ///
    /// When a child router is detached:
    /// 1. The child's interactor is deactivated
    /// 2. The child is removed from the ``children`` array
    /// 3. Leak detection is triggered to verify proper cleanup
    ///
    /// - Parameter child: The child router to detach. Must be currently attached.
    func detachChild(_ child: Routing)
}

/// The base class for routers that do not own view controllers.
///
/// `Router` is the core class that manages application state and the napkin tree structure.
/// It owns an ``Interactor`` and drives its lifecycle based on attachment state.
///
/// ## Overview
///
/// A router serves as the backbone of a napkin unit:
/// - It owns and manages the lifecycle of its associated ``Interactor``
/// - It maintains a tree of child routers via ``attachChild(_:)`` and ``detachChild(_:)``
/// - It coordinates navigation and state transitions
///
/// ## Lifecycle
///
/// The router has two main lifecycle events:
/// 1. **Loading**: When ``load()`` is called (internally by the framework), ``didLoad()`` is invoked
/// 2. **Activation**: When attached to a parent, the interactor is activated; when detached, it's deactivated
///
/// ## Usage
///
/// Subclass `Router` to create custom routers:
///
/// ```swift
/// final class MyFeatureRouter: Router<MyFeatureInteractor>, MyFeatureRouting {
///
///     private let detailsBuilder: DetailsBuildable
///     private var detailsRouter: DetailsRouting?
///
///     init(interactor: MyFeatureInteractor, detailsBuilder: DetailsBuildable) {
///         self.detailsBuilder = detailsBuilder
///         super.init(interactor: interactor)
///         interactor.router = self
///     }
///
///     override func didLoad() {
///         super.didLoad()
///         // Attach any permanent child routers here
///     }
///
///     func routeToDetails(withId id: String) {
///         guard detailsRouter == nil else { return }
///         let router = detailsBuilder.build(withListener: interactor, id: id)
///         detailsRouter = router
///         attachChild(router)
///     }
///
///     func routeBackFromDetails() {
///         guard let router = detailsRouter else { return }
///         detachChild(router)
///         detailsRouter = nil
///     }
/// }
/// ```
///
/// ## Topics
///
/// ### Creating a Router
///
/// - ``init(interactor:)``
///
/// ### Lifecycle
///
/// - ``load()``
/// - ``didLoad()``
/// - ``lifecycle``
///
/// ### Managing Children
///
/// - ``attachChild(_:)``
/// - ``detachChild(_:)``
/// - ``children``
///
/// ### Accessing the Interactor
///
/// - ``interactor``
/// - ``interactable``
///
/// - SeeAlso: ``Routing``
/// - SeeAlso: ``ViewableRouter``
/// - SeeAlso: ``Interactor``
open class Router<InteractorType>: Routing {

    /// The strongly-typed interactor owned by this router.
    ///
    /// Use this property to access the specific interactor type with all its custom methods and properties.
    /// The router drives this interactor's lifecycle based on attachment state.
    public let interactor: InteractorType

    /// The interactor as an ``Interactable`` protocol reference.
    ///
    /// This property provides access to the base interactor lifecycle methods.
    /// It's used internally by the framework for activation and deactivation.
    public let interactable: Interactable

    /// The child routers currently attached to this router.
    ///
    /// This array is automatically updated when children are attached or detached.
    /// Children are stored in the order they were attached.
    public final var children: [Routing] = []

    /// A publisher that emits router lifecycle events.
    ///
    /// Subscribe to this publisher to observe when the router completes loading.
    /// The publisher completes when the router is deallocated.
    ///
    /// - SeeAlso: ``RouterLifecycle``
    public final var lifecycle: AnyPublisher<RouterLifecycle, Never> {
        return lifecycleSubject.eraseToAnyPublisher()
    }

    /// Creates a router with the specified interactor.
    ///
    /// The interactor must conform to ``Interactable``. If it doesn't, this initializer
    /// will trigger a fatal error.
    ///
    /// - Parameter interactor: The interactor that this router will own and manage.
    /// - Precondition: The interactor must conform to ``Interactable``.
    public init(interactor: InteractorType) {
        self.interactor = interactor
        guard let interactable = interactor as? Interactable else {
            fatalError("\(interactor) should conform to \(Interactable.self)")
        }
        self.interactable = interactable
    }

    /// Loads the router and prepares it for use.
    ///
    /// This method is called internally by the framework when the router is attached.
    /// It triggers the ``didLoad()`` callback and emits a lifecycle event.
    ///
    /// - Important: Do not call this method directly. The framework manages loading automatically.
    public final func load() {
        guard !didLoadFlag else {
            return
        }

        didLoadFlag = true
        internalDidLoad()
        didLoad()
    }

    /// Called once when the router finishes loading.
    ///
    /// Override this method to perform one-time setup, such as attaching permanent child routers.
    /// Always call `super.didLoad()` when overriding.
    ///
    /// ```swift
    /// override func didLoad() {
    ///     super.didLoad()
    ///     // Attach permanent children
    ///     let tabBarRouter = tabBarBuilder.build(withListener: interactor)
    ///     attachChild(tabBarRouter)
    /// }
    /// ```
    open func didLoad() {
        // No-op
    }

    // We cannot declare the attach/detach child methods to take in concrete `Router` instances,
    // since during unit testing, we need to use mocked child routers.

    /// Attaches a child router to this router.
    ///
    /// This method:
    /// 1. Adds the child to the ``children`` array
    /// 2. Activates the child's interactor
    /// 3. Loads the child router (if not already loaded)
    ///
    /// - Parameter child: The router to attach as a child.
    /// - Precondition: The child must not already be attached to this router.
    ///
    /// - Important: Always store a reference to attached children so you can detach them later.
    public final func attachChild(_ child: Routing) {
        assert(!(children.contains { $0 === child }), "Attempt to attach child: \(child), which is already attached to \(self).")

        children.append(child)

        // Activate child first before loading. Router usually attaches immutable children in didLoad.
        // We need to make sure the napkin is activated before letting it attach immutable children.
        child.interactable.activate()
        child.load()
    }

    /// Detaches a child router from this router.
    ///
    /// This method:
    /// 1. Deactivates the child's interactor (triggering ``Interactor/willResignActive()``)
    /// 2. Removes the child from the ``children`` array
    ///
    /// After detaching, you should clear your reference to the child router.
    ///
    /// - Parameter child: The child router to detach.
    public final func detachChild(_ child: Routing) {
        child.interactable.deactivate()
        children.removeAll { $0 === child }
    }

    // MARK: - Internal


    func internalDidLoad() {
        bindSubtreeActiveState()
        lifecycleSubject.send(.didLoad)
    }

    // MARK: - Private

    private let lifecycleSubject = PassthroughSubject<RouterLifecycle, Never>()
    private var cancellables = Set<AnyCancellable>()
    private var didLoadFlag: Bool = false

    private func bindSubtreeActiveState() {

        let cancellable = interactable.isActiveStream
            // Do not retain self here to guarantee execution. Retaining self will cause the dispose bag
            // to never be disposed, thus self is never deallocated. Also cannot just store the disposable
            // and call dispose(), since we want to keep the subscription alive until deallocation, in
            // case the router is re-attached. Using weak does require the router to be retained until its
            // interactor is deactivated.
            .sink { [weak self] (isActive: Bool) in
                // When interactor becomes active, we are attached to parent, otherwise we are detached.
                self?.setSubtreeActive(isActive)
            }
        cancellables.insert(cancellable)
    }

    private func setSubtreeActive(_ active: Bool) {

        if active {
            iterateSubtree(self) { router in
                if !router.interactable.isActive {
                    router.interactable.activate()
                }
            }
        } else {
            iterateSubtree(self) { router in
                if router.interactable.isActive {
                    router.interactable.deactivate()
                }
            }
        }
    }

    private func iterateSubtree(_ root: Routing, closure: (_ node: Routing) -> ()) {
        closure(root)

        for child in root.children {
            iterateSubtree(child, closure: closure)
        }
    }

    private func detachAllChildren() {

        for child in children {
            detachChild(child)
        }
    }

    deinit {
        interactable.deactivate()

        if !children.isEmpty {
            detachAllChildren()
        }

        lifecycleSubject.send(completion: .finished)

        LeakDetector.instance.expectDeallocate(object: interactable)
    }
}
