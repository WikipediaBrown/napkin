# ``napkin``

@Metadata {
    @PageImage(purpose: icon, source: "napkin-icon", alt: "napkin logo")
    @PageColor(blue)
    @CallToAction(
        url: "https://github.com/WikipediaBrown/napkin",
        purpose: link,
        label: "View on GitHub")
}

A Swift 6.2 framework for building app architecture as a tree of small, isolated, composable units — *napkins* — modeled on Uber's RIBs but rebuilt from the ground up around Swift Concurrency.

## Overview

A **napkin** is one node in your application tree. Every napkin is built from a small, fixed set of rings:

| Ring | Isolation | Role |
| --- | --- | --- |
| ``Builder`` | `Sendable` class | Constructs the napkin: builds the component, instantiates interactor and router, wires the listener. |
| ``Component`` | `Sendable` class | The DI container. Provides services to this napkin and conforms to its children's `Dependency` protocols. |
| ``Interactable`` | `final actor` | The unit's brain. Holds business state, drives the lifecycle, calls the presenter and router. |
| ``Routing`` | `@MainActor` class | Owns the subtree. Attaches and detaches child routers; in viewable napkins it also owns a view controller. |
| ``Presentable`` | `@MainActor` class | View-state holder. Optional — view controllers can conform directly when there is no separate state to hold. |
| ``ViewControllable`` | `@MainActor` class | The platform view. A `UIHostingController` wrapping a SwiftUI `View`, or any `UIViewController` / `NSViewController`. |

### Why protocol composition over inheritance

Earlier RIBs frameworks shipped an `open class PresentableInteractor<P>` that subclasses extended. Swift Concurrency removes that option. Per [SE-0306](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0306-actors.md), actors cannot be subclassed; per [SE-0316](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0316-global-actors.md), only Apple-blessed types like `MainActor` may be `@globalActor`. A `@MainActor open class` base would put business logic on the main actor, violating the dependency rule of clean architecture.

napkin's answer is protocol composition. ``Interactable`` is a protocol that refines `Actor`; conforming types are `final actor`. A protocol extension on ``Interactable`` provides default implementations of every lifecycle method, forwarding state to a single shared helper, ``InteractorLifecycle``. The result behaves exactly like a base class — overrides, inherited defaults, polymorphic dispatch — without the inheritance.

See <doc:ProtocolCompositionOverInheritance> for the full reasoning, including the primitives table and links to Apple's evolution proposals.

### The actor-isolation map

Each ring lives in a specific isolation domain, and crossings are explicit:

![The napkin actor-isolation map: Sendable Builder/Component, @MainActor Router/Presenter/ViewController, and final actor Interactor with arrows showing creates/injects/owns/await/dispatch crossings.](isolation-map)

- **Interactor → Presenter** crosses `actor → @MainActor`: `await presenter.update(...)`.
- **Interactor → Router** crosses `actor → @MainActor`: `await router?.routeToProfile()`.
- **View → Interactor** crosses `@MainActor sync → actor`: `dispatch { await listener?.didTap() }`.
- **Interactor → Listener** stays in the listener's actor: `await listener?.fooDidFinish()`.

See <doc:CrossIsolationPatterns> for the full set of directional patterns and when each is appropriate.

### Where to start

- New to napkin? Begin with <doc:GettingStarted>.
- Want to see a real app, line by line? <doc:TutorialBuildingALoginFlow> walks through the example end to end.
- Building your first feature? <doc:DefiningAFeature> walks through every file.
- Migrating an older RIBs / pre-2.0 codebase? <doc:MigratingFromV0> shows the conversion line by line.
- Wondering "why is it shaped this way?" — <doc:ProtocolCompositionOverInheritance>.

A runnable end-to-end reference, **Napkin's Rib House**, lives at `Examples/RibHouse/` in the repository. The tracked `RibHouse.xcodeproj` opens directly.

## Topics

### Getting Started

- <doc:GettingStarted>
- <doc:TutorialBuildingALoginFlow>
- <doc:DefiningAFeature>
- <doc:MigratingFromV0>

### Tutorials

- <doc:TestingANapkin>
- <doc:AddingANetworkedService>
- <doc:TabBarNapkin>

### Architecture Reference

- <doc:ProtocolCompositionOverInheritance>
- <doc:CrossIsolationPatterns>
- <doc:HeadlessNapkins>
- <doc:SwiftUIIntegration>
- <doc:Glossary>

### Defining a Napkin

- ``Interactable``
- ``PresentableInteractable``
- ``InteractorLifecycle``
- ``InteractorScope``

### Routing

- ``Routing``
- ``Router``
- ``ViewableRouting``
- ``ViewableRouter``
- ``LaunchRouting``
- ``LaunchRouter``

### Presenting

- ``Presentable``
- ``Presenter``
- ``ViewControllable``

### Dependency Injection

- ``Dependency``
- ``EmptyDependency``
- ``Component``
- ``EmptyComponent``
- ``Buildable``
- ``Builder``
- ``ComponentizedBuilder``
- ``SimpleComponentizedBuilder``
- ``MultiStageComponentizedBuilder``
- ``SimpleMultiStageComponentizedBuilder``

### View Events

- ``dispatch(priority:_:)``
