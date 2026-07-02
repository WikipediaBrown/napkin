# Headless Napkins

Napkins without a presenter or a view: analytics workers, deep-link handlers, auth gates, root coordinators. When the right shape is a napkin without a face.

## Overview

Not every napkin owns a piece of the screen. A long-lived analytics worker that listens to user events and ships them to a backend doesn't need a view. A deep-link handler that watches for incoming URLs and routes the user to the right place is purely behavioral. An auth gate that decides whether to show login or the main app is a routing decision, not a screen.

These are *headless napkins*. They use ``Interactable`` (not ``PresentableInteractable``) and ``Router`` (not ``ViewableRouter``). They participate in the napkin tree exactly like viewable ones — they have a builder, a component, a lifecycle, listeners — they just don't have a presenter or a view controller.

## Anatomy

A headless napkin is three files instead of five.

### AnalyticsBuilder.swift

```swift
import napkin

protocol AnalyticsDependency: Dependency {
    var eventBus: EventBus { get }
    var analyticsClient: AnalyticsClient { get }
}

final class AnalyticsComponent: Component<AnalyticsDependency>, @unchecked Sendable {}

protocol AnalyticsBuildable: Buildable {
    @MainActor func build(withListener listener: AnalyticsListener) async -> AnalyticsRouting
}

final class AnalyticsBuilder:
    Builder<AnalyticsDependency>,
    AnalyticsBuildable,
    @unchecked Sendable
{
    @MainActor
    func build(withListener listener: AnalyticsListener) async -> AnalyticsRouting {
        let interactor = AnalyticsInteractor(
            eventBus: dependency.eventBus,
            analyticsClient: dependency.analyticsClient
        )
        let router = AnalyticsRouter(interactor: interactor)
        await interactor.wire(router: router, listener: listener)
        return router
    }
}
```

The builder shape is identical to a viewable napkin's builder — it just doesn't construct a view controller.

### AnalyticsInteractor.swift

```swift
import napkin

@MainActor
protocol AnalyticsRouting: Routing, Sendable {}

protocol AnalyticsListener: AnyObject, Sendable {
    func analyticsDidFailFatally() async
}

final actor AnalyticsInteractor: Interactable {

    nonisolated let lifecycle = InteractorLifecycle()

    weak var router: AnalyticsRouting?
    weak var listener: AnalyticsListener?

    private let eventBus: EventBus
    private let analyticsClient: AnalyticsClient

    init(eventBus: EventBus, analyticsClient: AnalyticsClient) {
        self.eventBus = eventBus
        self.analyticsClient = analyticsClient
    }

    func wire(router: AnalyticsRouting?, listener: AnalyticsListener?) {
        self.router = router
        self.listener = listener
    }

    func didBecomeActive() async {
        task {
            for await event in self.eventBus.events() {
                do {
                    try await self.analyticsClient.send(event)
                } catch {
                    // Log and continue; only escalate truly fatal errors.
                }
            }
        }
    }
}
```

**Why ``Interactable`` and not ``PresentableInteractable``.** There's no presenter to declare. ``PresentableInteractable`` adds exactly one requirement (``PresentableInteractable/presenter``); when there's nothing to present, you don't need it.

**Why a router at all.** Even a headless napkin participates in the tree. Its router holds its place in the parent's children list and gives the parent a handle to attach and detach. If this napkin had children of its own — say, sub-workers spawned per session — the router would attach them too.

### AnalyticsRouter.swift

```swift
import napkin

@MainActor
final class AnalyticsRouter: Router<AnalyticsInteractor>, AnalyticsRouting {

    override init(interactor: AnalyticsInteractor) {
        super.init(interactor: interactor)
    }
}
```

That's it. ``Router`` is generic over the interactor type only; there is no view controller in scope.

## How the parent attaches a headless napkin

Identical to a viewable napkin — except there is no view controller to embed. The parent router's `routeToAnalytics()` method just builds and attaches:

```swift
@MainActor
final class RootRouter: ViewableRouter<RootInteractor, RootViewControllable>, RootRouting {

    private let analyticsBuilder: AnalyticsBuildable
    private var analyticsRouter: AnalyticsRouting?

    func startAnalytics() async {
        let r = await analyticsBuilder.build(withListener: interactor)
        await attachChild(r)
        analyticsRouter = r
    }

    func stopAnalytics() async {
        guard let r = analyticsRouter else { return }
        await detachChild(r)
        analyticsRouter = nil
    }
}
```

`attachChild` calls ``Interactable/activate()`` on the analytics interactor; ``Interactable/didBecomeActive()`` runs and the worker begins listening on the event bus. `detachChild` deactivates it; the bound `task { ... }` is cancelled, the event-bus loop ends, and the worker tears down cleanly.

## When to make a napkin headless

Reach for a headless napkin when:

- The unit has a *lifecycle* — there's a defined moment it should start working and a defined moment it should stop, and that lifecycle is shorter than the application's.
- The unit has *its own listener contract* — it emits events upstream that the parent decides what to do with.
- The unit benefits from *the napkin tree's automatic teardown* — bound tasks, cascading deactivation, removal of the subtree.

Reach for a *viewable* napkin instead when there is a screen the user sees. Reach for a plain service in the component (no napkin at all) when the unit is just stateless logic the rest of the tree calls into synchronously.

## Common headless shapes

- **Auth gate.** Listens to an auth-state stream and routes to login or the main app.
- **Deep-link handler.** Listens for URL events and asks its parent (or a child router) to route.
- **Analytics / telemetry worker.** Subscribes to an event bus and ships events out.
- **Background sync.** Periodically reconciles local state with a remote source while the user is in a particular flow.
- **Root coordinator.** A root napkin that owns several headless children (auth gate + deep linker + analytics) plus the viewable main flow.

## See Also

- <doc:DefiningAFeature>
- <doc:CrossIsolationPatterns>
- ``Router``
- ``Interactable``
