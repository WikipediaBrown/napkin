# Migrating From v0.x

A real, line-by-line migration of a hypothetical v0.x feature to napkin v2.0.0. We'll convert a `HomeInteractor` that subclasses `PresentableInteractor<HomePresentable>` and uses Combine, alongside its router, presenter, and listener protocols.

## Overview

v2.0.0 is a Swift 6.2 / iOS 26 rearchitecture. The major moves are:

- ``Interactable``, ``PresentableInteractable``, ``InteractorLifecycle`` (protocols + helper) replace the old `Interactor` / `PresentableInteractor<P>` base classes. Interactors become `final actor`.
- Combine `cancellables` and `.sink(...)` are gone. Use ``Interactable/task(priority:_:)`` with `for await` over an `AsyncStream` / `AsyncSequence`.
- All listener and presenter methods are `async`. There is no synchronous interactor method that signals across rings.
- Lifecycle methods no longer call `super.didBecomeActive()`. The default protocol implementation is a no-op; you simply implement the method and your code is the body.
- `attachChild` and `detachChild` are `async` and `@MainActor`-isolated. Wrapping them in `Task { @MainActor in ... }` from inside the interactor is replaced by `await router?.attachX()` — the router does the work.

## Side-by-side migration

A typical v0.x file set on the left, the v2.0.0 equivalent on the right. Treat each row as one file.

### `HomeInteractor.swift`

@Row {
    @Column {
        **Before (v0.x)**

        ```swift
        // v0.x — DO NOT WRITE NEW CODE THIS WAY
        import RIBs
        import Combine

        protocol HomeRouting: ViewableRouting {
            func routeToProfile()
        }

        protocol HomePresentable: Presentable {
            var listener: HomePresentableListener? { get set }
            func update(user: User)
        }

        protocol HomeListener: AnyObject {
            func homeDidLogout()
        }

        final class HomeInteractor: PresentableInteractor<HomePresentable>,
                                    HomeInteractable,
                                    HomePresentableListener {

            weak var router: HomeRouting?
            weak var listener: HomeListener?

            private let userService: UserService
            private var cancellables = Set<AnyCancellable>()

            init(presenter: HomePresentable, userService: UserService) {
                self.userService = userService
                super.init(presenter: presenter)
                presenter.listener = self
            }

            override func didBecomeActive() {
                super.didBecomeActive()
                userService.userPublisher
                    .sink { [weak self] user in
                        self?.presenter.update(user: user)
                    }
                    .store(in: &cancellables)
            }

            override func willResignActive() {
                super.willResignActive()
                cancellables.removeAll()
            }

            func didTapProfile() {
                router?.routeToProfile()
            }

            func didTapLogout() {
                listener?.homeDidLogout()
            }
        }
        ```
    }
    @Column {
        **After (v2.0.0)**

        ```swift
        import napkin

        @MainActor
        protocol HomeRouting: ViewableRouting, Sendable {
            func routeToProfile() async
        }

        protocol HomePresentable: Presentable, Sendable {
            @MainActor var listener: HomePresentableListener? { get set }
            func update(user: User) async
        }

        protocol HomeListener: AnyObject, Sendable {
            func homeDidLogout() async
        }

        final actor HomeInteractor: PresentableInteractable, HomePresentableListener {

            nonisolated let lifecycle = InteractorLifecycle()
            nonisolated let presenter: HomePresentable

            weak var router: HomeRouting?
            weak var listener: HomeListener?

            private let userService: UserService

            init(presenter: HomePresentable, userService: UserService) {
                self.presenter = presenter
                self.userService = userService
            }

            func set(router: HomeRouting?) { self.router = router }
            func set(listener: HomeListener?) { self.listener = listener }

            func didBecomeActive() async {
                await MainActor.run { presenter.listener = self }

                task {
                    for await user in self.userService.userStream {
                        await self.presenter.update(user: user)
                    }
                }
            }

            func willResignActive() async {
                await MainActor.run { presenter.listener = nil }
                // No manual task cancellation — the lifecycle cancels bound
                // tasks for us after this method returns.
            }

            func didTapProfile() async {
                await router?.routeToProfile()
            }

            func didTapLogout() async {
                await listener?.homeDidLogout()
            }
        }
        ```
    }
}

### `HomeRouter.swift`

@Row {
    @Column {
        **Before (v0.x)**

        ```swift
        // v0.x
        final class HomeRouter: ViewableRouter<HomeInteractable, HomeViewControllable>, HomeRouting {

            private let profileBuilder: ProfileBuildable
            private var profileRouter: ViewableRouting?

            init(interactor: HomeInteractable,
                 viewController: HomeViewControllable,
                 profileBuilder: ProfileBuildable) {
                self.profileBuilder = profileBuilder
                super.init(interactor: interactor, viewController: viewController)
            }

            func routeToProfile() {
                let r = profileBuilder.build(withListener: interactor)
                attachChild(r)
                viewController.present(r.viewControllable.uiviewController, animated: true)
                profileRouter = r
            }
        }
        ```
    }
    @Column {
        **After (v2.0.0)**

        ```swift
        import napkin

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
                viewController.uiviewController.present(
                    r.viewControllable.uiviewController,
                    animated: true
                )
                profileRouter = r
            }
        }
        ```
    }
}

## Diff, line by line

| v0.x | v2.0.0 | Why |
| --- | --- | --- |
| `final class HomeInteractor: PresentableInteractor<HomePresentable>` | `final actor HomeInteractor: PresentableInteractable, HomePresentableListener` | Actors can't subclass; ``PresentableInteractable`` is a protocol with default lifecycle implementations. See <doc:ProtocolCompositionOverInheritance>. |
| `super.init(presenter: presenter)` | `nonisolated let presenter: HomePresentable; init(presenter: ...) { self.presenter = presenter }` | No base class to call into. The presenter is a stored `nonisolated` property declared by ``PresentableInteractable``. |
| (none) | `nonisolated let lifecycle = InteractorLifecycle()` | Required by ``Interactable``. Holds active-state, bound tasks, and the `AsyncStream` continuations. |
| `private var cancellables = Set<AnyCancellable>()` | *(deleted)* | Combine is gone. Bound tasks via ``Interactable/task(priority:_:)`` replace `disposeOnDeactivate`. |
| `override func didBecomeActive() { super.didBecomeActive(); … }` | `func didBecomeActive() async { … }` | No `super` to call. ``Interactable/didBecomeActive()``'s default impl is a no-op; your body is the override. |
| `userPublisher.sink { … }.store(in: &cancellables)` | `task { for await user in userService.userStream { … } }` | `for await` over an `AsyncStream` replaces Combine subscription. The `task { ... }` binds it to the active scope. |
| `override func willResignActive() { super.willResignActive(); cancellables.removeAll() }` | `func willResignActive() async { … }` | No manual task cancellation — the lifecycle cancels bound tasks automatically *after* `willResignActive()` returns. |
| `presenter.update(user: user)` (sync) | `await presenter.update(user: user)` | Presenter is `@MainActor`; the interactor is an actor. Crossing requires `await`. |
| `init(...) { … presenter.listener = self }` | `await MainActor.run { presenter.listener = self }` inside `didBecomeActive()` | The presenter is `@MainActor`; setting its listener requires being on the main actor. Doing it in `didBecomeActive()` (rather than `init`) also keeps the wiring tied to the active scope. |
| `router?.routeToProfile()` (sync) | `await router?.routeToProfile()` | Router is `@MainActor`. |
| `protocol HomeListener { func homeDidLogout() }` | `protocol HomeListener: AnyObject, Sendable { func homeDidLogout() async }` | Listeners cross isolation domains (parent's actor). They are `Sendable` and their methods are `async`. |
| `attachChild(r)` (sync) | `await attachChild(r)` | ``Routing/attachChild(_:)`` is `async` because it awaits the child's ``Interactable/activate()``. |
| `super.init(interactor: interactor, viewController: viewController)` in router | Same | ``ViewableRouter`` is still a class; this initializer is unchanged. |

## What you don't have to change

The `Builder` and `Component` rings are largely the same:

- ``Builder`` is still `Builder<DependencyType>` and still owns a `let dependency`.
- ``Component`` is still `Component<DependencyType>` and still uses ``Component/shared(forCallerKey:_:)`` for cached singletons.
- The dependency-protocol-as-the-public-shape pattern is unchanged.

The only difference: a v2.0.0 builder's `build` method is `@MainActor func build(withListener:) async`. The `async` is needed because building a napkin involves an `await interactor.set(listener:)` call to wire the listener onto the actor.

## A migration checklist

1. **Imports.** Replace `import RIBs` with `import napkin`. Delete `import Combine` everywhere.
2. **Class → actor.** For each interactor: `final class FooInteractor: PresentableInteractor<P>` → `final actor FooInteractor: PresentableInteractable`.
3. **Add the lifecycle.** `nonisolated let lifecycle = InteractorLifecycle()`.
4. **Add the presenter as a stored property.** `nonisolated let presenter: FooPresentable`. Set it from `init`.
5. **Delete every `super.` lifecycle call.** Lifecycle methods are protocol defaults, not inherited code.
6. **Make every listener and presenter method `async`.** Annotate the protocols with `Sendable`.
7. **Replace `cancellables` / `.sink`.** Convert publishers to `AsyncStream` (or `AsyncSequence` of choice). Subscribe via `task { for await … in … }`.
8. **Add `await` everywhere you cross isolation.** The compiler will tell you exactly where.
9. **Make `attachChild` / `detachChild` `await`-ed.** Anywhere you call them.
10. **Make builders `@MainActor`-isolated and their build methods `async`.**
11. **Run the build.** Swift 6.2's data-race-safety diagnostics will surface any remaining cross-isolation issues; fix them with `await` or by restructuring.

## See Also

- <doc:GettingStarted>
- <doc:ProtocolCompositionOverInheritance>
- <doc:CrossIsolationPatterns>
- <doc:DefiningAFeature>
