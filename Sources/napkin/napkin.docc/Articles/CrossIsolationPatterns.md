# Cross-Isolation Patterns

The four directional flows that move data and events through a napkin tree, what isolation domain each side lives in, and when each pattern is the right one.

## Overview

A napkin sits at the intersection of three isolation domains: the actor (interactor), the main actor (router, presenter, view), and the parent's actor (listener). Almost everything you write in a napkin is one of four cross-isolation calls. This article shows the shape of each, the *why*, and how to pick between `task(_:)` and an unstructured `Task` when both seem to fit.

## Pattern 1 — Interactor → Presenter

`actor → @MainActor`. The interactor finishes computing some state and tells the presenter to render it.

```swift
final actor ProfileInteractor: PresentableInteractable {
    nonisolated let lifecycle = InteractorLifecycle()
    nonisolated let presenter: ProfilePresentable

    func didBecomeActive() async {
        let user = await userService.currentUser
        await presenter.update(displayName: "\(user.firstName) \(user.lastName)")
    }
}
```

**Why this shape.** The interactor holds business state and runs on its own actor. The presenter holds view state and is `@MainActor`-isolated so SwiftUI and UIKit can read it synchronously. Crossing requires `await`. The presenter property is `nonisolated` (declared on ``PresentableInteractable``) so that *holding* the reference doesn't require hopping to the actor; only invoking methods does.

**When you reach for it.** Any time the interactor has computed something the user should see — a fetched value, a state transition, an error message.

## Pattern 2 — Interactor → Router

`actor → @MainActor`. The interactor decides "we should now show child X" and asks the router to make it happen.

```swift
final actor HomeInteractor: PresentableInteractable {
    nonisolated let lifecycle = InteractorLifecycle()
    nonisolated let presenter: HomePresentable

    weak var router: HomeRouting?
    weak var listener: HomeListener?

    func didTapProfile() async {
        await router?.routeToProfile()
    }

    func profileDidFinish() async {
        await router?.detachProfile()
    }
}
```

The router itself looks like:

```swift
@MainActor
final class HomeRouter: ViewableRouter<HomeInteractor, HomeViewControllable>, HomeRouting {

    private let profileBuilder: ProfileBuildable
    private var profileRouter: ProfileRouting?

    init(
        interactor: HomeInteractor,
        viewController: HomeViewControllable,
        profileBuilder: ProfileBuildable
    ) {
        self.profileBuilder = profileBuilder
        super.init(interactor: interactor, viewController: viewController)
    }

    func routeToProfile() async {
        let r = await profileBuilder.build(withListener: interactor)
        await attachChild(r)
        // Present r.viewControllable here.
        profileRouter = r
    }

    func detachProfile() async {
        guard let r = profileRouter else { return }
        await detachChild(r)
        profileRouter = nil
    }
}
```

**Why this shape.** Routers manipulate the view tree, so they live on the main actor. The interactor calling into them is the routing decision *originating* in business logic and *executing* in UI land — exactly the seam this design exists to make explicit.

**Why `weak var router`.** The router strongly owns the interactor. The interactor's reference back must be weak to avoid a cycle.

## Pattern 3 — View → Interactor

`@MainActor sync → actor`. A button is tapped on the main actor; we need to forward the event into the actor, where it is processed asynchronously, without making the button handler itself async.

```swift
struct ProfileView: View {
    weak var listener: ProfilePresentableListener?

    var body: some View {
        Button("Done") {
            dispatch { [listener] in await listener?.didTapDone() }
        }
    }
}
```

**Why this shape.** `Button`'s action closure is `() -> Void` and runs synchronously on `@MainActor`. The listener is the interactor (an actor), and its method is `async`. ``dispatch(priority:_:)`` spawns an unstructured `Task` so the synchronous handler can return immediately while the work proceeds.

**Why `dispatch` rather than inlining `Task { ... }`.** They're equivalent — ``dispatch(priority:_:)`` is `Task(priority:)` — but the named function communicates intent ("this is a one-shot view event being forwarded to the actor"), and gives a single grep-able call site for "where do view events leave the view layer."

**Why a `weak` capture.** The view's `listener` property is `weak`. The captured value remains weak. If the actor goes away while the dispatched task is in flight, the call is a no-op.

## Pattern 4 — Interactor → Listener (Parent's Actor)

`actor → parent's actor`. A child interactor signals an event back up to its parent through the listener protocol.

```swift
protocol ProfileListener: AnyObject, Sendable {
    func profileDidFinish() async
}

final actor ProfileInteractor: PresentableInteractable {
    weak var listener: ProfileListener?

    func didTapDone() async {
        await listener?.profileDidFinish()
    }
}
```

The parent (typically `HomeInteractor`) conforms:

```swift
final actor HomeInteractor: PresentableInteractable, ProfileListener {
    func profileDidFinish() async {
        await router?.detachProfile()
    }
}
```

**Why this shape.** The listener protocol is the child's *contract with its parent*: "here are the events I emit; you decide what to do with them." Because both child and parent are actors (potentially different ones), the methods are `async`. `Sendable` on the protocol is required because the listener crosses isolation domains.

**Why `weak`.** The parent owns the child (router → interactor). The reverse reference must be weak.

**When you reach for it.** Whenever a child needs to tell its parent something happened that the parent owns the response to: a flow completed, the user dismissed a modal, a deep link resolved. The child never reaches up directly into the parent or its siblings; everything goes through the listener.

## When to use `task(_:)` vs an unstructured `Task`

Inside an interactor you have two ways to spawn concurrent work. They are not interchangeable.

### Use ``Interactable/task(priority:_:)`` for active-scope-bound work

When the work *should be cancelled when the interactor deactivates*. This is the rule for almost every observation pattern: stream subscriptions, repeating timers, anything that watches an external source.

```swift
func didBecomeActive() async {
    task {
        for await event in eventStream {
            await self.handle(event)
        }
    }
}
```

The lifecycle holds a strong reference to the spawned task and cancels it inside ``Interactable/deactivate()`` after ``Interactable/willResignActive()`` returns. This replaces the role of `disposeOnDeactivate` from upstream RIBs.

### Use an unstructured `Task { ... }` for fire-and-forget work that should outlive the active scope

When you genuinely want the work to continue after the napkin deactivates — flushing analytics, finalizing a network write that must complete. This is rare. If you find yourself reaching for it, double-check whether the work belongs to *this* napkin at all.

```swift
func willResignActive() async {
    Task { await analytics.flush() } // intentionally unbound
}
```

### Use `await ...` directly for sequential work inside a lifecycle method

When the work is a single linear sequence that you want to complete before the lifecycle method returns:

```swift
func didBecomeActive() async {
    let user = await userService.currentUser
    await presenter.update(user: user)
}
```

This is the simplest case. No spawning, no cancellation concern — the lifecycle method itself is awaited by ``Interactable/activate()``.

## See Also

- <doc:DefiningAFeature>
- <doc:HeadlessNapkins>
- <doc:SwiftUIIntegration>
