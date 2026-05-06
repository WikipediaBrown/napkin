//
//  Copyright (c) 2017. Uber Technologies
//  Licensed under the Apache License, Version 2.0
//

import Foundation

/// The base protocol for all routers.
///
/// `Routing` is `@MainActor`-isolated because routers manipulate the view
/// tree. Lifecycle methods are `async` because they must `await` actor-isolated
/// `Interactable` calls.
@MainActor
public protocol Routing: AnyObject {
    var interactable: Interactable { get }
    var children: [Routing] { get }

    /// Loads the router and prepares it for use. Triggers `didLoad()`.
    func load() async

    /// Returns once `didLoad()` has completed for this router. Subsequent calls
    /// return immediately. Replaces the `lifecycle` Combine publisher.
    func loaded() async

    /// Attach a child router. Activates the child's interactor, then loads it.
    func attachChild(_ child: Routing) async

    /// Detach a child router. Deactivates its interactor and removes it from
    /// `children`.
    func detachChild(_ child: Routing) async
}

/// The base class for routers that do not own a view controller.
///
/// `Router` is `@MainActor`-isolated. Its `_children` array is plain mutable
/// state; no locks are needed.
@MainActor
open class Router<InteractorType>: Routing {

    public let interactor: InteractorType
    public let interactable: Interactable

    public final var children: [Routing] { _children }

    public init(interactor: InteractorType) {
        self.interactor = interactor
        guard let interactable = interactor as? Interactable else {
            fatalError("\(interactor) should conform to \(Interactable.self)")
        }
        self.interactable = interactable
    }

    public final func load() async {
        guard !didLoadFlag else { return }
        didLoadFlag = true
        await didLoad()
        for c in loadedContinuations { c.resume() }
        loadedContinuations.removeAll()
    }

    public final func loaded() async {
        if didLoadFlag { return }
        await withCheckedContinuation { continuation in
            loadedContinuations.append(continuation)
        }
    }

    /// Override to perform one-time setup, such as attaching permanent child
    /// routers. Always call `super.didLoad()` when overriding.
    open func didLoad() async {}

    public final func attachChild(_ child: Routing) async {
        assert(!_children.contains { $0 === child },
               "Attempt to attach child: \(child), which is already attached.")
        _children.append(child)
        await child.interactable.activate()
        await child.load()
    }

    public final func detachChild(_ child: Routing) async {
        await child.interactable.deactivate()
        _children.removeAll { $0 === child }
    }

    // MARK: - Private

    private var didLoadFlag: Bool = false
    private var _children: [Routing] = []
    private var loadedContinuations: [CheckedContinuation<Void, Never>] = []

    isolated deinit {
        // We're on the main actor; can synchronously empty children and fire
        // a best-effort deactivate on each interactor.
        let snapshot = _children
        _children.removeAll()
        for child in snapshot {
            let interactable = child.interactable
            Task { await interactable.deactivate() }
        }
        let interactable = self.interactable
        Task { await interactable.deactivate() }
        for c in loadedContinuations { c.resume() }
        loadedContinuations.removeAll()
    }
}
