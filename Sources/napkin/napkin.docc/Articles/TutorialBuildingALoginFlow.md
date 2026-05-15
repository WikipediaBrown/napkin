# Tutorial: Building a Login Flow

A walkthrough of **Napkin's Rib House** (`Examples/RibHouse`): two child napkins, a service held by the parent, dependencies declared from the top down.

@Metadata {
    @PageImage(purpose: card, source: "napkin-icon", alt: "napkin icon")
    @PageColor(green)
}

## Overview

This tutorial walks through the napkin example app, [`Examples/RibHouse`](https://github.com/WikipediaBrown/napkin/tree/main/Examples/RibHouse). When you're done you'll have an end-to-end mental model of how the rings — Builder, Component, Interactor, Router, ViewController — work together for a parent napkin with two children, an injected service, and a real user-driven state transition.

**What we're building.** An iOS app whose root is a *headless* `LaunchNapkin` that holds an `AuthService`. The Launch napkin starts by attaching a `LoggedOutNapkin` (one **Login** button). When the user taps it, the Launch interactor calls `authService.login()`, gets back a `User`, and tells its router to swap to a `LoggedInNapkin` that shows the user's name and a list of barbecue foods. Tapping **Logout** reverses the flow.

```
LaunchNapkin (headless container, holds AuthService)
├── LoggedOutNapkin   (Login button → listener?.loggedOutDidTapLogin())
└── LoggedInNapkin    (Logout button → listener?.loggedInDidTapLogout())
```

Only one child is attached at a time. The parent's router enforces this by detaching the other before attaching.

## Step 1: The data + service boundary

Start at the *bottom*: the data types and the service contract. These define the shape of what flows through everything else.

The `User` is a plain `Sendable` value:

```swift
struct User: Sendable, Equatable {
    let name: String
    let barbecueFoods: [String]
}
```

The `AuthService` is a `Sendable` protocol with two async-throws methods. The mock implementation is synchronous because the goal is to demonstrate the design, not simulate network latency.

```swift
protocol AuthService: Sendable {
    func login() async throws -> User
    func logout() async throws
}

final class BarbecueAuthService: AuthService {
    func login() async throws -> User {
        User(
            name: "Smokey Joe",
            barbecueFoods: ["Brisket", "Pulled Pork", "St. Louis Ribs", "Burnt Ends", "Smoked Sausage"]
        )
    }
    func logout() async throws {}
}
```

`Sendable` here is the contract that this service can be passed across actor boundaries — important because the LaunchInteractor (an `actor`) will hold and call it.

## Step 2: The dependency root

Every napkin tree starts from a root component. In the example, that's `AppComponent` in `SceneDelegate.swift`:

```swift
final class AppComponent: Component<EmptyDependency>, LaunchNapkinDependency, @unchecked Sendable {
    let authService: AuthService

    init(authService: AuthService = BarbecueAuthService()) {
        self.authService = authService
        super.init(dependency: EmptyComponent())
    }
}
```

Two things to notice:

- **`Component<EmptyDependency>`** — the root has nothing above it, so it depends on `Nothing`.
- **`LaunchNapkinDependency`** — the AppComponent conforms to the *child's* dependency protocol. This is the napkin DI pattern: a component is the union of its own internal scope plus the conformance to its children's needs.

## Step 3: The LaunchNapkin (parent, holds the service)

A napkin has up to six files. Let's walk through them in the order they get built.

### Dependency

```swift
protocol LaunchNapkinDependency: Dependency {
    var authService: AuthService { get }
}
```

The parent declares **what it needs from above**. The `AppComponent` satisfied this requirement in the previous step.

### Component

```swift
final class LaunchNapkinComponent: Component<LaunchNapkinDependency>, @unchecked Sendable {
    var authService: AuthService { dependency.authService }
}

extension LaunchNapkinComponent: LoggedOutNapkinDependency, LoggedInNapkinDependency {}
```

The Launch component:

1. **Surfaces** the parent-provided `authService` so the builder can read it.
2. **Bridges** to the children: child napkin `Dependency` protocols are declared empty (or with their own needs) — the parent's component conforms to them so it can be passed as `dependency:` when constructing child builders.

### Builder

```swift
final class LaunchNapkinBuilder: Builder<LaunchNapkinDependency>, LaunchNapkinBuildable, @unchecked Sendable {

    @MainActor
    func build(withListener listener: LaunchNapkinListener) async -> LaunchNapkinRouting {
        let component = LaunchNapkinComponent(dependency: dependency)
        let loggedOutBuilder = LoggedOutNapkinBuilder(dependency: component)
        let loggedInBuilder = LoggedInNapkinBuilder(dependency: component)
        let viewController = LaunchNapkinViewController()
        let interactor = LaunchNapkinInteractor(authService: component.authService)
        await interactor.set(listener: listener)
        let router = LaunchNapkinRouter(
            interactor: interactor,
            viewController: viewController,
            loggedOutBuilder: loggedOutBuilder,
            loggedInBuilder: loggedInBuilder
        )
        await interactor.set(router: router)
        return router
    }
}
```

The build sequence:

1. Construct the component from the parent's dependency.
2. Construct the **child napkin builders** with `component` as their dependency.
3. Construct the view controller (a plain UIViewController — this napkin is headless).
4. Construct the interactor and **inject the service** via the component.
5. Wire the listener (the parent of LaunchNapkin, here `AppListener`).
6. Construct the router, **inject the child builders**, return it.

### Interactor

The interactor holds the service and contains all the business logic.

```swift
final actor LaunchNapkinInteractor:
    Interactable,
    LoggedOutNapkinListener,
    LoggedInNapkinListener
{
    nonisolated let lifecycle = InteractorLifecycle()
    nonisolated let authService: AuthService

    weak var router: LaunchNapkinRouting?

    init(authService: AuthService) {
        self.authService = authService
    }

    func didBecomeActive() async {
        await router?.attachLoggedOut()
    }

    // Triggered by the LoggedOutNapkin's button tap.
    func loggedOutDidTapLogin() async {
        do {
            let user = try await authService.login()
            await router?.attachLoggedIn(user: user)
        } catch {
            // Real apps would surface this; the demo stays silent.
        }
    }

    // Triggered by the LoggedInNapkin's button tap.
    func loggedInDidTapLogout() async {
        try? await authService.logout()
        await router?.attachLoggedOut()
    }
}
```

Key points:

- **`final actor`** — business logic is off the main actor.
- **`Interactable`** (not `PresentableInteractable`) — Launch has no presenter because it has no view of its own.
- **`nonisolated let authService`** — `Sendable` service, safe to expose nonisolated; the actor reads it directly without crossing its own boundary.
- **Conforms to both child listener protocols** — `LoggedOutNapkinListener` for the Login intent, `LoggedInNapkinListener` for the Logout intent. The router will hand `interactor` to each child's builder as their listener.

### Router

```swift
@MainActor
final class LaunchNapkinRouter:
    LaunchRouter<LaunchNapkinInteractor, LaunchNapkinViewControllable>,
    LaunchNapkinRouting
{
    private let loggedOutBuilder: LoggedOutNapkinBuildable
    private let loggedInBuilder: LoggedInNapkinBuildable
    private var loggedOutRouter: LoggedOutNapkinRouting?
    private var loggedInRouter: LoggedInNapkinRouting?

    func attachLoggedOut() async {
        await detachLoggedInIfNeeded()
        guard loggedOutRouter == nil else { return }
        let router = await loggedOutBuilder.build(withListener: interactor)
        loggedOutRouter = router
        await attachChild(router)
        viewController.embed(router.viewControllable)
    }

    func attachLoggedIn(user: User) async {
        await detachLoggedOutIfNeeded()
        guard loggedInRouter == nil else { return }
        let router = await loggedInBuilder.build(withListener: interactor, user: user)
        loggedInRouter = router
        await attachChild(router)
        viewController.embed(router.viewControllable)
    }

    private func detachLoggedOutIfNeeded() async {
        guard let router = loggedOutRouter else { return }
        loggedOutRouter = nil
        viewController.detach(router.viewControllable)
        await detachChild(router)
    }
    // detachLoggedInIfNeeded mirrors the above.
}
```

The pattern to internalize:

- **Each attach method removes the other child first.** This ensures only one is ever active and the framework's lifecycle invariants hold.
- **`pingBuilder.build(withListener: interactor)`** — the router passes *its own interactor* as the listener to the child. That's how the listener chain is hooked up.
- **`attachChild(...)`** activates the child's lifecycle (calls its `didBecomeActive`). `detachChild(...)` reverses it.
- **`viewController.embed(...)`** is a method on the LaunchNapkin's `ViewControllable` protocol — the router calls it to add the child's view to the parent's UIKit hierarchy.

### ViewController

LaunchNapkin's view controller is a plain `UIViewController` (not a hosting controller), because it doesn't render its own SwiftUI — it embeds children.

```swift
@MainActor
final class LaunchNapkinViewController: UIViewController, LaunchNapkinViewControllable {

    func embed(_ child: ViewControllable) {
        let childVC = child.uiviewController
        addChild(childVC)
        childVC.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(childVC.view)
        NSLayoutConstraint.activate([
            childVC.view.topAnchor.constraint(equalTo: view.topAnchor),
            childVC.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            childVC.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            childVC.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        childVC.didMove(toParent: self)
    }

    func detach(_ child: ViewControllable) {
        let childVC = child.uiviewController
        childVC.willMove(toParent: nil)
        childVC.view.removeFromSuperview()
        childVC.removeFromParent()
    }
}
```

Standard UIKit child-view-controller plumbing.

## Step 4: A child napkin (LoggedOutNapkin)

The children follow the same six-file shape as the parent but in miniature.

### Dependency, Component, Builder

```swift
protocol LoggedOutNapkinDependency: Dependency {}

final class LoggedOutNapkinComponent: Component<LoggedOutNapkinDependency>, @unchecked Sendable {}

final class LoggedOutNapkinBuilder: Builder<LoggedOutNapkinDependency>, LoggedOutNapkinBuildable, @unchecked Sendable {
    @MainActor
    func build(withListener listener: LoggedOutNapkinListener) async -> LoggedOutNapkinRouting {
        let viewController = LoggedOutNapkinViewController()
        let interactor = LoggedOutNapkinInteractor(presenter: viewController)
        await interactor.set(listener: listener)
        let router = LoggedOutNapkinRouter(interactor: interactor, viewController: viewController)
        await interactor.set(router: router)
        return router
    }
}
```

Empty dependency because LoggedOutNapkin needs nothing from above (no service of its own). The parent's component still satisfies the protocol — `LaunchNapkinComponent: LoggedOutNapkinDependency` is an empty conformance.

### Interactor

```swift
protocol LoggedOutNapkinListener: AnyObject, Sendable {
    func loggedOutDidTapLogin() async
}

final actor LoggedOutNapkinInteractor: PresentableInteractable, LoggedOutNapkinPresentableListener {
    nonisolated let lifecycle = InteractorLifecycle()
    nonisolated let presenter: LoggedOutNapkinPresentable
    weak var listener: LoggedOutNapkinListener?

    // PresentableListener: view → this actor
    func didTapLogin() async {
        // Listener: this actor → parent (Launch)
        await listener?.loggedOutDidTapLogin()
    }
}
```

Two listener types live in this file:

- **`LoggedOutNapkinPresentableListener`** — the view talks down to the interactor through this.
- **`LoggedOutNapkinListener`** — the interactor talks *up* to the parent through this. The parent (LaunchInteractor) conforms to it.

That's the napkin listener pattern. Each napkin's interactor forwards user intent upward via the `listener?.xxxDidYyy()` method.

### View

```swift
struct LoggedOutNapkinView: View {
    weak var listener: LoggedOutNapkinPresentableListener?

    var body: some View {
        VStack(spacing: 28) {
            Text("Step inside the *smokehouse*.")
            Button("Login") {
                dispatch { [listener] in await listener?.didTapLogin() }
            }
        }
    }
}
```

The `dispatch { ... }` helper is napkin's bridge from `@MainActor` SwiftUI action closures into the interactor's `actor` — it spawns a `Task` and forwards the call. See <doc:CrossIsolationPatterns> for why this pattern is preferred over inline `Task { ... }`.

## Step 5: The other child napkin (LoggedInNapkin)

LoggedInNapkin is the same shape, with two notable differences.

### Dependency declares the AuthService

```swift
protocol LoggedInNapkinDependency: Dependency {
    var authService: AuthService { get }
}

final class LoggedInNapkinComponent: Component<LoggedInNapkinDependency>, @unchecked Sendable {
    var authService: AuthService { dependency.authService }
}
```

Even though LoggedInNapkin doesn't currently *call* the service (only LaunchInteractor does), the dependency is declared so:

- The component contract documents what's available.
- Future versions of the napkin can read the service without re-wiring.
- The parent (`LaunchNapkinComponent`) already exposes `authService`, so its existing `extension LaunchNapkinComponent: LoggedInNapkinDependency {}` automatically satisfies the new requirement.

### User flows all the way through to the router

```swift
protocol LoggedInNapkinBuildable: Buildable {
    @MainActor func build(
        withListener listener: LoggedInNapkinListener,
        user: User
    ) async -> LoggedInNapkinRouting
}

final class LoggedInNapkinBuilder: ... {
    @MainActor
    func build(
        withListener listener: LoggedInNapkinListener,
        user: User
    ) async -> LoggedInNapkinRouting {
        let viewController = LoggedInNapkinViewController(user: user)
        let interactor = LoggedInNapkinInteractor(presenter: viewController, user: user)
        await interactor.set(listener: listener)
        let router = LoggedInNapkinRouter(
            interactor: interactor,
            viewController: viewController,
            user: user
        )
        await interactor.set(router: router)
        return router
    }
}
```

The `user` parameter threads the full chain: `LaunchInteractor` → `LaunchRouter.attachLoggedIn(user:)` → `loggedInBuilder.build(withListener:, user:)` → `LoggedInNapkinViewController(user:)` / `LoggedInNapkinInteractor(... , user:)` / `LoggedInNapkinRouter(... , user:)`.

The data flows along the same path as the routing call. The router holds it as `let user: User`; the view receives it via `UIHostingController(rootView: LoggedInNapkinView(user: user))`.

## Step 6: The SceneDelegate

```swift
final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private var launchRouter: LaunchNapkinRouting?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: ...) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: windowScene)
        self.window = window

        Task { @MainActor in
            let builder = LaunchNapkinBuilder(dependency: AppComponent())
            let router = await builder.build(withListener: AppListener())
            self.launchRouter = router
            await router.launch(from: window)
        }
    }
}
```

The bootstrap is three steps:

1. Build the `AppComponent` (the dependency root).
2. Build the root router via `LaunchNapkinBuilder`.
3. Call `launch(from: window)`, which installs the root view controller, activates the interactor, and starts the tree.

## Wrapping up

The full data flow on a login tap:

```
LoggedOutView.Login tap
  → LoggedOutInteractor.didTapLogin()             (PresentableListener)
  → listener?.loggedOutDidTapLogin()              (LoggedOutNapkinListener)
  → LaunchInteractor.loggedOutDidTapLogin()       (Launch conforms to the listener)
  → try await authService.login()
  → router?.attachLoggedIn(user: user)
  → LaunchRouter detaches LoggedOut, builds LoggedIn(user:), attaches + embeds.
```

What that demonstrates:

- **Composition over inheritance.** No `class FooInteractor: BaseInteractor`. The actor conforms to `Interactable`; lifecycle is delegated to ``InteractorLifecycle``.
- **Explicit isolation crossings.** View `@MainActor` → actor `Interactor` via `dispatch`. Actor → router `@MainActor` via `await`. Actor → service `Sendable` via plain call.
- **DI through the dependency chain.** The parent's component conforms to its children's dependency protocols. Services injected at the top reach the leaves without anyone hand-rolling a singleton.
- **Listener pattern for upward communication.** Children never import or reference their parent — they communicate intent through a `<Self>NapkinListener` protocol that the parent's interactor implements.

For the deeper *why* on each piece:

- <doc:ProtocolCompositionOverInheritance> — why napkin doesn't ship a `PresentableInteractor<P>` base class.
- <doc:CrossIsolationPatterns> — the four directional patterns for crossing actor boundaries.
- <doc:HeadlessNapkins> — when (and why) a napkin can be a pure orchestrator with no view.
- <doc:SwiftUIIntegration> — `dispatch`, `UIHostingController` glue, and SwiftUI-specific concurrency notes.

For the running code: [`Examples/RibHouse`](https://github.com/WikipediaBrown/napkin/tree/main/Examples/RibHouse). Open the project file directly — `xcodegen` is no longer required.
