//
//  Copyright (c) 2017. Uber Technologies
//  Licensed under the Apache License, Version 2.0
//

import Foundation
import Synchronization

/// The base class for dependency injection components in the napkin
/// architecture.
///
/// A `Component` serves as the dependency-injection container for a napkin
/// unit. It defines the dependencies that the napkin provides to its own
/// internal pieces (``Router``, ``Interactable``, ``Presenter``, view) and
/// to its child napkins.
///
/// ## Overview
///
/// In the napkin architecture, components form a tree that mirrors the
/// router tree:
///
/// - Each napkin owns a `Component` subclass.
/// - The component receives the parent's component as its
///   ``dependency`` and conforms to its own children's `Dependency`
///   protocols, which lets it satisfy each child's required services.
/// - The component creates instances of services that this napkin owns,
///   typically using ``shared(_:)`` so that multiple consumers see the same
///   instance.
///
/// ## Creating a Component
///
/// Subclass `Component`, parameterize it on the parent's `Dependency`, and
/// conform to the dependency protocols of any child napkins this napkin
/// builds:
///
/// ```swift
/// protocol HomeDependency: Dependency {
///     var userService: UserService { get }
/// }
///
/// final class HomeComponent: Component<HomeDependency>,
///                            ProfileDependency,
///                            SettingsDependency {
///
///     // Pass-through from the parent.
///     var userService: UserService { dependency.userService }
///
///     // Lazily created and cached for the lifetime of this component.
///     var homeAnalytics: HomeAnalytics {
///         shared { HomeAnalytics(userService: dependency.userService) }
///     }
///
///     // A non-shared dependency: a fresh instance each call.
///     var requestBuilder: RequestBuilder {
///         RequestBuilder(userService: dependency.userService)
///     }
/// }
/// ```
///
/// ## Shared vs Non-Shared Dependencies
///
/// Use ``shared(_:)`` for instances that should be reused across consumers
/// — services, caches, anything stateful that you want to live as long as
/// the napkin does:
///
/// ```swift
/// var imageCache: ImageCache {
///     shared { ImageCache() }
/// }
/// ```
///
/// Return a fresh instance from the computed property when each consumer
/// should get its own object — request builders, mutable state holders,
/// per-call helpers:
///
/// ```swift
/// var requestBuilder: RequestBuilder {
///     RequestBuilder(userService: dependency.userService)
/// }
/// ```
///
/// `shared(_:)` keys cached instances by `#function`, so each computed
/// property in your component gets its own slot automatically — no manual
/// keying required.
///
/// ## Concurrency
///
/// `Component` is `Sendable`. Shared instances created via ``shared(_:)``
/// are stored under a `Mutex` from the `Synchronization` module, so they
/// may be retrieved from any actor or thread safely. ``shared(_:)`` is
/// safe to call concurrently; the framework guarantees the factory runs at
/// most once per call site.
///
/// ## Subclassing
///
/// `Component` declares `@unchecked Sendable` because it is `open` and
/// generic. The `@unchecked` annotation **inherits to subclasses** without
/// the compiler re-verifying their stored properties. If a subclass adds
/// non-`Sendable` mutable state, that state is silently unsafe to share
/// across actors. Either keep stored properties immutable and `Sendable`,
/// or use a `Mutex` / `Synchronization.OSAllocatedUnfairLock` to guard
/// them. The framework's own state (``dependency`` is `let`,
/// `sharedInstances` is a `Mutex`) is genuinely safe; the subclass
/// obligation is on you.
///
/// ## Topics
///
/// ### Creating a Component
///
/// - ``init(dependency:)``
/// - ``dependency``
///
/// ### Sharing Instances
///
/// - ``shared(__function:_:)``
///
/// - SeeAlso: ``Dependency``
/// - SeeAlso: ``EmptyComponent``
/// - SeeAlso: ``Builder``
open class Component<DependencyType>: Dependency, @unchecked Sendable {

    /// The dependency object provided by the parent component.
    ///
    /// Typed as the parent's `Dependency` protocol so that this component
    /// can read pass-through services from the parent without depending on
    /// the parent's concrete type.
    public let dependency: DependencyType

    /// Creates a component with the specified parent dependency.
    ///
    /// - Parameter dependency: The dependency object provided by the
    ///   parent napkin. Typically the parent's ``Component`` instance,
    ///   passed in by the napkin's builder.
    public init(dependency: DependencyType) {
        self.dependency = dependency
    }

    /// Returns a shared instance produced by `factory`, cached for the
    /// lifetime of this component.
    ///
    /// The factory closure is invoked at most once per call site;
    /// subsequent calls at the same call site return the cached instance.
    /// Call sites are keyed on `#function`, so each computed property in
    /// your component gets its own cache slot automatically:
    ///
    /// ```swift
    /// var imageCache: ImageCache {
    ///     shared { ImageCache() }                 // Slot: imageCache
    /// }
    ///
    /// var analytics: AnalyticsService {
    ///     shared { AnalyticsService() }           // Slot: analytics
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - __function: Implicit cache key. Defaults to `#function` so each
    ///     computed property yields a stable, unique key. Do not pass an
    ///     explicit value unless you have a deliberate reason to share or
    ///     separate slots.
    ///   - factory: A closure that creates the instance the first time
    ///     this call site is hit.
    /// - Returns: The cached instance, or a freshly created one if this is
    ///   the first call at this site.
    /// - Important: The factory is invoked while `sharedInstances` is
    ///   locked. Do not transitively call `shared(_:)` on the same
    ///   component from inside a factory — `Mutex` is non-recursive and you
    ///   will deadlock.
    public final func shared<T>(__function: String = #function, _ factory: () -> T) -> T {
        sharedInstances.withLock { storage in
            // The double-optional cast is load-bearing: when `T` is itself an
            // `Optional`, this preserves a previously cached `nil` factory
            // result instead of re-running the factory each call. Simplifying
            // to `as? T` would silently change semantics for optional-typed
            // shared dependencies.
            if let existing = (storage[__function] as? T?) ?? nil {
                return existing
            }
            let instance = factory()
            storage[__function] = instance
            return instance
        }
    }

    // MARK: - Private

    private let sharedInstances = Mutex<[String: Any]>([:])
}

/// A component for root napkins that have no parent dependencies.
///
/// `EmptyComponent` is the canonical "no upstream dependency" terminator.
/// Use it as the parent dependency of an application's root component when
/// the root has nothing to inherit:
///
/// ```swift
/// final class AppComponent: Component<EmptyDependency>, RootDependency {
///     init() {
///         super.init(dependency: EmptyComponent())
///     }
///
///     var userService: UserService {
///         shared { UserService() }
///     }
/// }
/// ```
///
/// - SeeAlso: ``EmptyDependency``
/// - SeeAlso: ``Component``
open class EmptyComponent: EmptyDependency, @unchecked Sendable {

    /// Creates an empty component. Takes no parameters; carries no state.
    public init() {}
}
