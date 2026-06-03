# The Interactor Lifecycle

How an interactor moves between inactive and active, what runs on each edge, and where the work you spawn gets cancelled for you.

## Overview

Every napkin's brain is an ``Interactable`` — a `final actor` that holds business state. Its *lifecycle* is the active-state machine the rest of the framework drives: a parent router activates the interactor when it attaches the napkin, and deactivates it when it detaches. You override two callbacks; napkin handles the transitions, the bound work, and the teardown.

```
  inactive
     │
     │  activate()             ← parent router, on attachChild
     ▼
  didBecomeActive()            you override: subscribe, observe, fetch
     │
     ▼
  ACTIVE                       isActive == true
     │                         task { } work runs here, bound to this scope
     │  deactivate()           ← parent router, on detachChild
     ▼
  willResignActive()           you override: flush, persist, notify listener
     │
     ▼
  every task { } is cancelled  →  back to inactive
```

You never call ``Interactable/activate()`` or ``Interactable/deactivate()`` yourself — the parent router does, through `attachChild`/`detachChild` (see <doc:GettingStarted>). Your job is the two override points, and choosing where work runs.

## The two callbacks you override

- ``Interactable/didBecomeActive()`` runs each time the interactor becomes active. Start observation here — stream subscriptions, timers, an initial fetch. The default implementation is a no-op.
- ``Interactable/willResignActive()`` runs once before the interactor goes inactive, *while* ``InteractorScope/isActive`` is still `true`. Flush state, persist, or notify the parent through the listener. The default implementation is a no-op.

Both are protocol default-implementation methods, so there is no `override` keyword and no `super` call.

## Bound work: `task { }`

Long-lived work — anything that watches an external source — goes in ``Interactable/task(priority:_:)``:

```swift
func didBecomeActive() async {
    task {
        for await user in userService.userStream {
            await presenter.presentUser(user)
        }
    }
}
```

The lifecycle retains that task and **cancels it for you** on ``Interactable/deactivate()``, right after `willResignActive()` returns — you write no manual teardown. This is napkin's replacement for `disposeOnDeactivate` from Uber's [RIBs](https://github.com/uber/ribs-ios). For when to reach for `task { }` versus an unstructured `Task` versus a plain `await`, see <doc:CrossIsolationPatterns>.

## Observing the active state

``InteractorScope`` is the read-only view of the lifecycle: ``InteractorScope/isActive`` for a point-in-time read, and ``InteractorScope/isActiveStream`` for an `AsyncStream<Bool>` that yields the current value immediately and then every subsequent transition. Use the stream to drive UI or coordinate siblings without exposing `activate()`/`deactivate()`.

## The full contract

The surface above is what you touch daily. The exact guarantees behind it live on ``InteractorLifecycle``: that ``Interactable/activate()`` and ``Interactable/deactivate()`` are idempotent, that a single non-recursive `Mutex` guards all lifecycle state, the precise ordering of `deactivate()` (claim → `willResignActive()` → flip state and drain tasks → cancel outside the lock), and the `deinit` backstop that cancels tasks and finishes streams when an interactor is released without an explicit deactivation. Together, `deactivate()` and that `deinit` backstop are why napkin needs no runtime leak detector.

## See Also

- ``InteractorLifecycle``
- ``InteractorScope``
- ``Interactable``
- <doc:CrossIsolationPatterns>
- <doc:GettingStarted>
