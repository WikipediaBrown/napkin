# Protocol Composition Over Inheritance

Why napkin's interactors are protocol-conforming `final actor`s rather than subclasses of an `open class` base — and what concurrency primitives stand in for the inheritance we used to lean on.

## Overview

If you've used Uber's [RIBs](https://github.com/uber/RIBs) or any of its descendants, you remember the shape: `class FooInteractor: PresentableInteractor<FooPresentable> { override func didBecomeActive() { super.didBecomeActive(); … } }`. That base class held active-state, managed a disposable bag, and provided lifecycle hooks for subclasses to override.

That shape is no longer available in modern Swift. This article is the complete reasoning behind the shape napkin landed on — protocol composition over inheritance — and the small kit of primitives that make it feel as ergonomic as the base class did.

This is the article consumers return to. If you understand it, every other shape in the framework follows.

## Why not an `open actor` base class?

Because actors cannot be subclassed.

[SE-0306: Actors](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0306-actors.md) introduces the `actor` keyword and explicitly disallows actor inheritance. The proposal says: *"Actor types cannot inherit from each other; an actor type can only have a non-actor superclass that is `NSObject`."* The inherited-isolation problem is genuinely hard — a subclass on a different actor would not share its parent's executor — and Swift's authors chose to defer it indefinitely.

So this is a compile error:

```swift
open actor BaseInteractor { ... }
final actor FooInteractor: BaseInteractor { ... } // error: actor types cannot inherit
```

The base class strategy is foreclosed at the language level for the most-isolated unit of the architecture.

## Why not a custom `@globalActor`?

Because Apple has not blessed it.

[SE-0316: Global Actors](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0316-global-actors.md) introduces `@globalActor` and ships exactly one usable instance: `@MainActor`. While the proposal allows third-party global actors, in practice the language and tooling treat `MainActor` as privileged: it is the only global actor that participates in `@preconcurrency` migration paths, isolation inference for `@objc`, and `@Observable`-friendly view code without ceremony.

Defining `@InteractorActor` and putting all interactors on it — even if it compiled — would cost you `MainActor` interop everywhere the interactor touches a view, a UIKit type, or an `@objc` API. The friction outpaces the benefit.

## Why not `@MainActor open class`?

Because it violates the dependency rule.

You *could* keep the inheritance-based shape if you put the base class on the main actor:

```swift
@MainActor open class PresentableInteractor<P> { ... }
```

Subclasses would inherit; everything would compile. But your business logic is now on the main actor by construction. Network parsing, business calculations, state transitions — all of it scheduled behind UIKit's executor. The whole point of the actor model is to *separate* business state from view-state and let them progress independently. Putting the interactor on the main actor surrenders that separation.

This violates the *dependency rule* of clean architecture: outer rings (UI) may depend on inner rings (use cases / business rules), but never the other way around. `@MainActor` on the interactor base class makes every interactor structurally bound to the UI's actor, which is the inversion the architecture exists to prevent.

## What napkin landed on

A protocol that refines `Actor`, plus a default-implementation extension, plus a single shared helper class for state.

### Primitives

| Primitive | Role |
| --- | --- |
| `final actor` conforming to ``Interactable`` | The concrete interactor. Holds business state. Final because actors can't inherit. |
| Protocol extension on ``Interactable`` | Provides default implementations of ``Interactable/activate()``, ``Interactable/deactivate()``, ``Interactable/task(priority:_:)``, ``InteractorScope/isActive``, ``InteractorScope/isActiveStream``. Plays the role of a base class's "inherited methods." |
| `nonisolated let lifecycle` of type ``InteractorLifecycle`` | The shared, mutable state — active flag, bound tasks, stream continuations — moved into a single non-actor class. Each interactor stores one of these. |
| `@unchecked Sendable` on ``InteractorLifecycle`` | The lifecycle uses a `Mutex<State>` from the `Synchronization` module. The class promises (and the implementation upholds) that every public operation reads or mutates state under the lock, never re-entering the lock, and never holding it across an `await`. |

### What that gives you

```swift
final actor ProfileInteractor: PresentableInteractable {

    nonisolated let lifecycle = InteractorLifecycle()
    nonisolated let presenter: ProfilePresentable

    init(presenter: ProfilePresentable) {
        self.presenter = presenter
    }

    func didBecomeActive() async {
        // No `super.didBecomeActive()` — it's a default protocol impl, not inherited code.
        task {
            for await event in someStream {
                await self.handle(event)
            }
        }
    }
}
```

The shape *behaves* like inheritance: ``Interactable/didBecomeActive()`` has a default no-op implementation; you "override" by simply implementing it; ``Interactable/activate()`` and ``Interactable/deactivate()`` are provided for free; ``Interactable/task(priority:_:)`` registers a task for automatic cancellation on deactivation; and ``InteractorScope/isActiveStream`` gives you an `AsyncStream` of transitions.

But because none of it is *real* inheritance, there's no `super` to call, no diamond problem, no risk of subclassing the actor. Each interactor is a final, sealed unit.

## Cross-references

- ``Interactable`` — the protocol every interactor conforms to.
- ``InteractorLifecycle`` — the helper class that holds the mutable state.
- ``InteractorScope`` — the read-only "is active" view, separated for testability.
- ``PresentableInteractable`` — the protocol for view-bearing napkins.

## Apple's primary sources

- [SE-0306: Actors](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0306-actors.md) — establishes that actors cannot inherit from one another.
- [SE-0316: Global Actors](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0316-global-actors.md) — defines `@globalActor` and `@MainActor`.
- [Migrating to Swift 6](https://www.swift.org/migration/documentation/migrationguide/) — Apple's official guide to the data-race safety rules that drive this design.
- [Synchronization module](https://developer.apple.com/documentation/synchronization) — `Mutex`, the primitive ``InteractorLifecycle`` uses internally.

## See Also

- <doc:CrossIsolationPatterns>
- <doc:MigratingFromV0>
