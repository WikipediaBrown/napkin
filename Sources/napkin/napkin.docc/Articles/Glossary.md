# Glossary

Domain terms used throughout the napkin docs, defined in one place.

@Metadata {
    @PageImage(purpose: icon, source: "napkin-icon", alt: "napkin logo")
    @PageColor(green)
}

## Overview

This is a reference for terminology used in the napkin codebase, documentation, articles, and example app. If a term appears across multiple articles, it's defined here once, with links to where it's used.

## Terms

### Actor isolation

The Swift 6 system that pins each piece of code to a specific concurrent execution domain. napkin uses four such domains: `final actor` for business logic, `@MainActor` for routing and presentation, `Sendable` classes for DI, and SwiftUI's implicit `@MainActor` for views. See <doc:CrossIsolationPatterns>.

### Attach / Detach

`attachChild(_:)` adds a child router to the parent's children array and **activates** the child's interactor lifecycle. `detachChild(_:)` reverses both. The framework's contract is that a child napkin's `didBecomeActive` runs exactly once per attach.

### Builder

The factory ring. Constructs the napkin's component, interactor, router, view controller, and wires them together. The builder takes a `Dependency` (what's needed from above) and returns a `Routing` (the napkin's external handle). `Sendable` class.

### Clean Architecture

Robert Martin's architecture pattern that organizes code by stability of dependencies: business logic depends only on protocols, never on UI frameworks; UI depends on those protocols, never on concrete business types. napkin enforces this with isolation: `actor` interactors (business) depend only on `Sendable` protocols; `@MainActor` views and routers depend on those protocols, never on concrete interactor types.

### Component

The DI container. A `Sendable` class typed over a feature's `Dependency` protocol; provides services to that feature and conforms to its children's `Dependency` protocols (typically by extension). The root component owns the actual service instances.

### Dependency (protocol)

The DI contract a feature requires from above. Declared as `protocol FooDependency: Dependency { var someService: SomeService { get } }`. The parent's component satisfies it. Compile-time checked.

### Dependency injection

The pattern of passing collaborators in from outside instead of constructing them or pulling them from a global. napkin uses dependency-tree DI: a tree of components, each conforming to its children's `Dependency` protocols. No runtime container, no annotation processor.

### Headless napkin

A napkin with no view of its own. Typically an orchestrator that routes between children. Its `ViewController` is a plain `UIViewController` (not a `UIHostingController`) that just embeds whichever child is active. See <doc:HeadlessNapkins>.

### Interactor

The brain ring. A `final actor` that holds business state, makes decisions, and drives the lifecycle. Talks to its presenter, its router, and its parent's listener — all via `await`. Conforms to ``Interactable`` (or ``PresentableInteractable`` if it owns a presenter).

### Lifecycle

The sequence `didBecomeActive` → (active) → `willResignActive`. Driven by `attachChild` / `detachChild` from the parent's router. Each interactor delegates state to a shared ``InteractorLifecycle`` helper via `nonisolated let lifecycle = InteractorLifecycle()`.

### Listener

How children talk to parents. Each napkin declares a `<Self>NapkinListener` protocol with the methods it can call upward (e.g. `counterDidFinish`). The parent's interactor conforms to that protocol. When the parent builds the child, it passes itself as the listener — children never import their parent.

### Napkin

One node in the application tree. Concretely, a folder of 5–6 Swift files (Builder, Component, Interactor, Router, View, ViewController) that implement a single feature. The name refers to the classic "back-of-the-napkin" architecture sketch.

### Presenter / Presentable

The view-state holder. A `@MainActor` protocol that the interactor talks to via `await presenter.update(...)`. Often realized by a `UIHostingController` that conforms to the `Presentable` protocol directly. Optional — many napkins skip the presenter and let the view controller hold state itself.

### Ring

One of the six conceptual layers a napkin is built from: Builder, Component, Interactor, Router, Presenter, ViewController. Each ring has a fixed isolation domain (see <doc:CrossIsolationPatterns>) and a fixed role.

### Router

The subtree-owner ring. A `@MainActor` class that holds references to child napkin routers, attaches/detaches them, and (for viewable napkins) owns a view controller. Calls `await attachChild` / `await detachChild` from the framework.

### Routing

The `@MainActor` protocol that exposes a router's API to its interactor. The interactor calls `await router?.routeToProfile()` to ask the router to spawn a child. The router decides what `routeToProfile` actually does (push, present, embed, swap).

### Sendable

A Swift 6 marker protocol indicating that a value can safely cross actor boundaries. All napkin services, models, and components are `Sendable`. Crossing a non-`Sendable` value across an actor boundary is a compile error.

### Swap routing

A routing pattern where the parent attaches only one child at a time, detaching the previous one before attaching the next. Used in the example app for `LoggedOutNapkin` ↔ `LoggedInNapkin`. Compare with concurrent routing (e.g. tab bar) where multiple children are attached simultaneously. See <doc:TabBarNapkin>.

### Tab bar routing

A routing pattern where the parent attaches multiple children concurrently and hosts them in a `UITabBarController`. All children stay active even when not visible. See <doc:TabBarNapkin>.

### ViewControllable

The platform-bridge protocol that exposes a `UIViewController` (UIKit) or `NSViewController` (AppKit) reference, so routers can present, embed, or push view controllers without depending on a concrete view class.

### View controller

The platform view ring. A `UIHostingController<SwiftUIView>` for SwiftUI features, or a `UIViewController` / `NSViewController` for UIKit features. Conforms to the feature's `Presentable` and `ViewControllable` protocols. `@MainActor`.

## See also

- <doc:GettingStarted>
- <doc:CrossIsolationPatterns>
- <doc:ProtocolCompositionOverInheritance>
- <doc:TutorialBuildingALoginFlow>
