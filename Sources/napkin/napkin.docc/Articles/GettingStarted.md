# Getting Started

A 30,000ft tour of napkin: what a napkin is, the rings each one is built from, and the direction data and events flow through the tree.

## Overview

napkin is an architecture framework for Apple-platform apps written in Swift 6.2. An app built with napkin is a **tree of napkins**, rooted at a single ``LaunchRouter`` and grown one feature at a time as the user navigates deeper. Each napkin is a self-contained slice of the application — login, home, profile, settings, an analytics worker, a deep-link handler — built from the same five (or six) rings.

A napkin is the smallest unit of feature in the app. If a piece of the UI has its own state, its own routing decisions, or its own listener contract with its parent, it is a napkin.

## Swift 6 setup (read this first if you hit an isolation error)

napkin's rings have **deliberate, mixed isolation**: ``Builder`` and ``Component`` are `nonisolated` (dependency-injection plumbing, off any actor), ``Router`` / ``ViewableRouter`` / ``LaunchRouter`` and ``Presentable`` are `@MainActor`, and interactors are `actor`s.

Xcode 26's new App template sets the build setting **Default Actor Isolation** to `MainActor` (Swift's "approachable concurrency", [SE-0466](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0466-control-default-actor-isolation.md)). In a module with that default, your `Builder`/`Component` subclasses are inferred `@MainActor`, so their `init(dependency:)` override no longer matches napkin's `nonisolated` base initializer:

```
Main actor-isolated initializer 'init(dependency:)' has different
actor isolation from nonisolated overridden declaration
```

This is not a napkin bug — it's the module default fighting the framework's intentional isolation. Two fixes:

- **Per type (recommended):** mark each napkin `Builder`/`Component` subclass `nonisolated`. The bundled Xcode templates already generate this:

  ```swift
  nonisolated final class HomeComponent: Component<HomeDependency>, @unchecked Sendable {}

  nonisolated final class HomeBuilder: Builder<HomeDependency>, HomeBuildable, @unchecked Sendable {
      override init(dependency: HomeDependency) { super.init(dependency: dependency) }
      // ...
  }
  ```

  Routers and view controllers stay `@MainActor`; interactors stay `actor`s. Only the DI plumbing needs `nonisolated`.

- **Per module:** set the target's **Default Actor Isolation** build setting to `nonisolated` (the pre-Xcode-26 behavior) if you'd rather opt the whole app out.

## The Five Rings

Every viewable napkin is composed of these files:

- **Builder.** A ``Builder`` (or ``ComponentizedBuilder``) subclass. The builder is the only thing the parent knows about. Its job is to take a parent's ``Dependency`` and produce a fully wired ``Routing``.
- **Component.** A ``Component`` subclass. Pure dependency injection. Knows how to produce every service this napkin and its children need.
- **Interactor.** A `final actor` conforming to ``Interactable`` or ``PresentableInteractable``. The brain. Owns business state. Talks to the presenter, talks to the router, listens to its parent through a `listener: ParentListener?` weak reference, and exposes its own listener protocol that its children call into.
- **Router.** A ``ViewableRouter`` (for napkins with a view) or ``Router`` (for headless ones). `@MainActor`. Holds the view controller, attaches and detaches child napkins.
- **Presenter** *(optional)*. A ``Presenter`` subclass conforming to a feature-specific `Presentable` protocol. `@Observable`-friendly view state. When there's no view-state worth holding, the view controller conforms to the presentable protocol directly and you skip the presenter object.
- **View.** A `UIViewController`, `NSViewController`, or — most commonly — a `UIHostingController` / `NSHostingController` wrapping a SwiftUI `View`. Conforms to ``ViewControllable``.

A *headless napkin* (analytics, deep-link routing, auth gate) skips the presenter and view rings entirely and uses ``Router`` directly. See <doc:HeadlessNapkins>.

## The Dependency Direction

> **Data flows down. Events flow up.**

- A parent napkin's ``Component`` provides the services its children need. Children declare what they need via a ``Dependency`` protocol; the parent's component conforms to that protocol. This is the only way data is shared between napkins.
- A child napkin's ``Interactable`` exposes a `Listener` protocol. The parent's interactor conforms to that protocol. When the child needs to tell its parent something happened ("user dismissed this screen", "this flow is done"), it calls `await listener?.someEventOccurred()`.
- Children never reach into siblings. Children never reach into ancestors except through the listener. This keeps each napkin testable in isolation and replaceable without touching its neighbors.

## The Lifecycle

The napkin lifecycle is asynchronous from end to end:

1. The parent's router calls `await childBuilder.build(withListener: interactor)` inside `routeToChild()`.
2. The parent calls `await attachChild(childRouter)`. This:
   - Activates the child's ``Interactable`` (calls ``Interactable/activate()``, which fires ``Interactable/didBecomeActive()``).
   - Calls `await childRouter.load()`, which fires ``Router/didLoad()``.
3. The child runs. Tasks spawned via ``Interactable/task(priority:_:)`` are bound to the active scope and cancelled automatically on detach.
4. To unwind, the parent calls `await detachChild(childRouter)`, which deactivates the interactor (firing ``Interactable/willResignActive()``), cancels every bound task, and detaches the subtree.

For the full state machine — idempotent activation, task binding, observing transitions via ``InteractorScope/isActiveStream``, and the concurrency guarantees behind it — see <doc:Lifecycle> and ``InteractorLifecycle``.

## What "a napkin" is

The name has two layers, both about being *clean*:

1. napkin is a fork of Uber's [RIBs](https://github.com/uber/ribs-ios) with RxSwift removed — clean of Rx.
2. napkin is an implementation of Clean Architecture — its dependency rule and isolation boundaries are enforced by Swift's type system and actor model.

A "napkin," then, is a single feature unit composed of a builder, interactor, router, and (when the unit owns a view) a presenter and view. A napkin tree is just napkins composed under one another, with each parent attaching children and routing between them.

## A runnable example

The repository ships **Napkin's Rib House** at `Examples/RibHouse/`. A headless `LaunchNapkin` holds an `AuthService`, then swaps between a `LoggedOutNapkin` (a single Login button) and a `LoggedInNapkin` (the user's name + a list of barbecue foods + Logout). Each child napkin lives in its own folder under `Sources/`. Read the tree top-down from `Sources/LaunchNapkin/LaunchNapkinBuilder.swift` to see how a real tree fits together — or skip to <doc:TutorialBuildingALoginFlow> for a guided walkthrough.

## Next

- <doc:TutorialBuildingALoginFlow> walks the example app end to end.
- <doc:DefiningAFeature> walks through building a feature file by file.
- <doc:CrossIsolationPatterns> covers the four cross-isolation flows you'll write daily.
- <doc:ProtocolCompositionOverInheritance> explains why the framework is shaped the way it is.
