# Defining a Feature

Build a single feature, file by file. We'll define a `Counter` napkin that displays a tappable count and exposes a "Done" button to its parent.

## Overview

This article walks through every file you write to define a viewable napkin. Each section explains *why* the file is shaped the way it is — not just what to type. By the end you will have a complete `Counter` napkin: builder, component, interactor, router, view controller, and SwiftUI view.

The walkthrough mirrors the runnable `Counter` napkin in `Examples/LaunchNapkinApp/Sources/CounterNapkin*.swift`. Open the example app alongside this article to compare the snippet with working code — the snippet here drops the `Napkin` infix (so types read `CounterBuilder` instead of `CounterNapkinBuilder`) but the structure is identical.

## CounterBuilder.swift

The builder is the only entry point a parent napkin sees. It owns the parent-supplied dependency, creates a ``Component`` for this napkin's own scope, instantiates the interactor and router, wires the listener, and returns the router as the public face of the napkin.

@Snippet(path: "napkin/Snippets/DefiningAFeature/CounterBuilder")

**Why `async @MainActor`.** The builder constructs view controllers, which are `@MainActor`-isolated. It also calls into the interactor (an actor) to wire the listener and the router. Both crossings require `await`, so the build method itself is `async`.

**Why two-phase wiring.** The interactor needs a router, and the router needs the interactor. We construct the interactor first, hand it to the router, then call `await interactor.set(router: router)`. This breaks the cycle without exposing a mutable property to the outside world; only the builder ever calls `set(router:)`.

## CounterInteractor.swift

The interactor is a `final actor`. It conforms to ``PresentableInteractable`` and to the listener protocol that its view emits.

@Snippet(path: "napkin/Snippets/DefiningAFeature/CounterInteractor")

**Why `final actor`.** Actors give us mutual-exclusion on stored state for free. `final` is required because actors cannot be subclassed (see <doc:ProtocolCompositionOverInheritance>).

**Why `nonisolated let lifecycle`.** ``Interactable`` requires a stored ``InteractorLifecycle``. Marking it `nonisolated` lets the parent router invoke ``Interactable/activate()`` and ``Interactable/deactivate()`` on this actor without first hopping into its executor — which matters because activation is itself the operation that schedules work on the actor.

**Why `weak var listener`.** The listener is the *parent's* interactor. Holding it strongly would create a retain cycle: parent retains child router → child router retains child interactor → child interactor retains parent → cycle.

**Why two `set(...)` methods.** Both `router` and `listener` are stored on the actor, so they can only be assigned by code running on the actor. The builder wires them via `await interactor.set(...)`.

**Why `MainActor.run` for `presenter.listener`.** The presenter is `@MainActor`-isolated. Setting its `listener` property requires being on the main actor. We hop briefly via `MainActor.run` rather than awaiting an async setter for clarity.

## CounterRouter.swift

The router is `@MainActor`. For a leaf napkin like Counter it does very little; for a feature with children it holds child builders and exposes `routeToX()` methods that the interactor calls.

@Snippet(path: "napkin/Snippets/DefiningAFeature/CounterRouter")

**Why generic over both interactor and view-controllable type.** ``ViewableRouter`` is `ViewableRouter<InteractorType, ViewControllerType>`. Storing the concrete `CounterInteractor` lets the router call into the actor with full type information; storing the `CounterViewControllable` protocol (rather than the concrete `CounterViewController`) keeps the router decoupled from the view's class.

**Why `@MainActor`.** Routers manipulate the view tree. Every method that pushes, presents, or embeds a view controller has to run on the main actor.

## CounterViewController.swift

The view controller is a `UIHostingController` (or `NSHostingController`) that wraps the SwiftUI view and conforms to the feature's ``Presentable`` protocol. In this small example the view controller doubles as the presenter — it has no view state worth holding separately.

@Snippet(path: "napkin/Snippets/DefiningAFeature/CounterViewController")

**Why `UIHostingController`.** It is the cheapest path from a SwiftUI `View` to something that conforms to ``ViewControllable``. The `UIKit` extension on `UIViewController` makes any UIKit view controller a ``ViewControllable`` automatically.

**Why a `weak` listener.** Same reasoning as in the interactor: the listener is owned upstream. The view should not retain the actor that retains it.

**Why `func update(count:) async`.** The presenter protocol's update methods are `async` because they are called from the interactor's actor — `await presenter.update(...)` from there hops onto the main actor.

## CounterView.swift

The SwiftUI view is a thin renderer. It reads from props passed in and forwards user events to the listener via ``dispatch(priority:_:)``.

@Snippet(path: "napkin/Snippets/DefiningAFeature/CounterView")

**Why `dispatch { ... }`.** SwiftUI button handlers are synchronous and `@MainActor`. The listener is an actor. ``dispatch(priority:_:)`` spawns an unstructured `Task` so the button can return immediately while the work `await`s the actor.

**Why `[listener]` capture.** `listener` is `weak`. We capture by value at the point of the tap so that the dispatched task gets a stable reference (still weak, since the property type is weak — you may also write `[weak listener]` for clarity).

## What you got

Six files. Each has a single, narrow responsibility. The builder is the only thing your parent imports. The interactor is the only thing that holds business state. The view stays a renderer. The router stays a tree manager. The component stays a DI container.

When you need to add a child feature, you do it from the router (`routeToChild()` calls a child builder, `await attachChild(...)`), give the child interactor a listener protocol, and conform the parent interactor to it.

## See Also

- <doc:CrossIsolationPatterns>
- <doc:HeadlessNapkins>
- <doc:SwiftUIIntegration>
