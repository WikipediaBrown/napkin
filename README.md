<p align="center">
  <img src="https://raw.githubusercontent.com/WikipediaBrown/napkin/develop/Tools/napkin/napkin.xctemplate/TemplateIcon%402x.png" alt="napkin logo" width="128" height="128">
</p>

# napkin

![Release Workflow](https://github.com/WikipediaBrown/napkin/actions/workflows/Release.yml/badge.svg)
[![Swift Versions](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FWikipediaBrown%2Fnapkin%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/WikipediaBrown/napkin)
[![Platforms Supported](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FWikipediaBrown%2Fnapkin%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/WikipediaBrown/napkin)

napkin is a fork of Uber's [RIBs](https://github.com/uber/RIBs) rebuilt on Swift 6.2 native concurrency. It structures iOS and macOS applications as a tree of modular units using the Router-Interactor-Builder pattern, with business logic running off the main actor and routing/presentation pinned to it.

## Table of Contents

- [Supported Platforms](#supported-platforms)
- [Installation](#installation)
- [Architecture Overview](#architecture-overview)
- [Concurrency Model](#concurrency-model)
- [Core Components](#core-components)
  - [Builder](#builder)
  - [Component & Dependency](#component--dependency)
  - [Interactor](#interactor)
  - [Router](#router)
  - [Presenter (Optional)](#presenter-optional)
  - [ViewControllable](#viewcontrollable)
- [Routing & Navigation](#routing--navigation)
- [Launching the App](#launching-the-app)
- [SwiftUI Integration](#swiftui-integration)
- [Testing](#testing)
- [Tooling](#tooling)
- [Versioning](#versioning)
- [Contributing](#contributing)
- [Author](#author)
- [License](#license)

## Supported Platforms

- iOS 26.0+
- macOS 26.0+

## Installation

Add napkin via [Swift Package Manager](https://swift.org/package-manager/):

1. In Xcode, navigate to **File** > **Add Package Dependencies...**
2. Paste the repository URL: `https://github.com/WikipediaBrown/napkin.git`
3. Click **Add Package**.

## Architecture Overview

napkin structures your app as a tree of units called "napkins." Each napkin encapsulates a feature and consists of:

```mermaid
flowchart LR
    subgraph napkin[" "]
        direction LR
        B([Builder]):::builder --> R([Router]):::core
        B --> I([Interactor]):::core
        B -.-> P([Presenter]):::optional
        R --> I
        R --> C([Child Routers]):::children
        P -.-> V([View]):::optional
    end

    classDef core fill:#4a90d9,stroke:#2c5aa0,color:#fff
    classDef builder fill:#50c878,stroke:#3a9a5c,color:#fff
    classDef optional fill:#f5f5f5,stroke:#999,color:#666,stroke-dasharray: 5 5
    classDef children fill:#ffb347,stroke:#cc8a2e,color:#fff
```

| Component | Required | Role |
|-----------|----------|------|
| **Builder** | Yes | Constructs the napkin, wires dependencies |
| **Component** | Yes | Provides dependencies to this napkin and its children |
| **Interactor** | Yes | Business logic, state management, lifecycle |
| **Router** | Yes | Manages the napkin tree (attach/detach children) |
| **Presenter** | No | Transforms business data into view-friendly formats |
| **View** | No | UIKit view controller or SwiftUI hosting controller |

Data flows down the tree. Events flow up via listener protocols.

## Concurrency Model

napkin uses Swift 6.2 native concurrency. Business logic in the Interactor runs **off the main actor by construction**; routing and presentation run on the main actor.

| Layer | Isolation |
|-------|-----------|
| `Interactable` (protocol) + per-feature `final actor` | `actor` |
| `InteractorLifecycle` (helper) | `final class @unchecked Sendable` (Mutex-protected) |
| `Router` / `ViewableRouter` / `LaunchRouter` | `@MainActor` |
| `Presenter` (`@Observable`) | `@MainActor` |
| `ViewControllable` | `@MainActor` |
| `Builder` / `Component` | non-isolated, `Sendable` |

Crossings between layers are explicit `await` points:

- Interactor → Router: `await router?.routeToProfile()`
- Interactor → Presenter: `await presenter.presentUser(user)`
- View → Interactor (events): `dispatch { await listener?.didTapLogout() }`

Combine has been removed. View-state changes flow through `@Observable` properties on the Presenter; lifecycle-bound subscriptions use `Interactor.task { for await … in Observations { … } }`.

### Why protocol composition instead of class inheritance?

Swift actors do not support inheritance (SE-0306). Rather than fall back to `@MainActor open class` (which would pin business logic to the main actor) or a custom `@globalActor` (which would serialize all interactors on one executor), napkin uses **protocol composition**: each feature's interactor is its own `final actor` conforming to `Interactable`. A small `InteractorLifecycle` helper class — the only `@unchecked Sendable` type in the framework — holds the mutex-protected state. Default implementations of `activate` / `deactivate` / `task(_:)` / `isActive` / `isActiveStream` come from a protocol extension that delegates to `lifecycle`.

### Divergence from Uber RIBs-iOS

Uber's `RIBs-iOS` PR #49 unifies the framework on `@MainActor` (Interactor included). napkin deliberately keeps the Interactor off the main actor so business logic is not pinned to the main thread. The cost is `await` at every cross-layer call; the benefit is enforced clean-architecture isolation.

## Core Components

### Builder

The **Builder** constructs a napkin and wires its dependencies. It receives a `Dependency` from its parent and returns a `Router`. `Builder` is `Sendable` and non-isolated.

When the napkin has a view, mark `build()` as `@MainActor async` — `@MainActor` because `UIViewController` initialization requires the main actor; `async` because wiring the actor-based interactor (e.g. setting the listener and router) requires `await`:

```swift
protocol HomeDependency: Dependency {
    var userService: UserServiceProtocol { get }
}

protocol HomeBuildable: Buildable {
    @MainActor func build(withListener listener: HomeListener) async -> HomeRouting
}

final class HomeBuilder: Builder<HomeDependency>, HomeBuildable {

    @MainActor
    func build(withListener listener: HomeListener) async -> HomeRouting {
        let component = HomeComponent(dependency: dependency)
        let viewController = HomeViewController()
        let interactor = HomeInteractor(
            presenter: viewController,
            userService: component.userService
        )
        await interactor.set(listener: listener)
        let router = HomeRouter(interactor: interactor, viewController: viewController)
        await interactor.set(router: router)
        return router
    }
}
```

For napkins without views, `build()` does not need `@MainActor`:

```swift
protocol AnalyticsBuildable: Buildable {
    func build(withListener listener: AnalyticsListener) async -> AnalyticsRouting
}
```

### Component & Dependency

A **Dependency** protocol declares what a napkin requires from its parent. A **Component** provides those dependencies and can create new ones for its children.

Use `shared {}` to create a single instance per component scope. Without `shared`, a new instance is created on each access. The `shared()` method is thread-safe.

```swift
protocol HomeDependency: Dependency {
    var analyticsService: AnalyticsServiceProtocol { get }
    var userSession: UserSession { get }
}

final class HomeComponent: Component<HomeDependency> {

    // Passed through from parent
    var analyticsService: AnalyticsServiceProtocol {
        dependency.analyticsService
    }

    // Created once, shared within this scope
    var userService: UserServiceProtocol {
        shared { UserService(session: dependency.userSession) }
    }

    // New instance each time
    var viewModel: HomeViewModel {
        HomeViewModel(service: userService)
    }
}
```

The root napkin uses `EmptyDependency`:

```swift
final class AppComponent: Component<EmptyDependency>, HomeDependency {
    var analyticsService: AnalyticsServiceProtocol {
        shared { AnalyticsService() }
    }
    var userSession: UserSession {
        shared { UserSession() }
    }
}
```

### Interactor

The **Interactor** contains all business logic. It is a `final actor` conforming to `Interactable` (or `PresentableInteractable` when paired with a view), and holds an `InteractorLifecycle` helper. Lifecycle is driven by its parent router: `didBecomeActive()` when attached, `willResignActive()` when detached. Both are `async`.

Interactors communicate:
- **Up** to parent napkins via `weak var listener` (a `Sendable` protocol the parent implements)
- **Down** to navigation via `weak var router` (an `@MainActor` routing protocol the router implements)

Listener and routing methods are `async` because they cross isolation boundaries.

```swift
protocol HomeListener: AnyObject, Sendable {
    func homeDidRequestLogout() async
}

@MainActor
protocol HomeRouting: ViewableRouting {
    func routeToProfile() async
}

protocol HomePresentable: Presentable, Sendable {
    @MainActor var listener: HomePresentableListener? { get set }
    func presentUser(_ user: User) async
}

final actor HomeInteractor: PresentableInteractable, HomePresentableListener {

    nonisolated let lifecycle = InteractorLifecycle()
    nonisolated let presenter: HomePresentable

    weak var router: HomeRouting?
    weak var listener: HomeListener?

    private let userService: UserServiceProtocol

    init(presenter: HomePresentable, userService: UserServiceProtocol) {
        self.presenter = presenter
        self.userService = userService
    }

    func set(router: HomeRouting?) { self.router = router }
    func set(listener: HomeListener?) { self.listener = listener }

    func didBecomeActive() async {
        // Lifecycle-bound subscription: cancelled automatically on willResignActive.
        task {
            for await user in Observations({ userService.currentUser }) {
                await presenter.presentUser(user)
            }
        }
    }

    func willResignActive() async {
        // Tasks started via `task { }` are cancelled automatically here.
    }

    // MARK: - HomePresentableListener

    func didTapProfile() async {
        await router?.routeToProfile()
    }

    func didTapLogout() async {
        await listener?.homeDidRequestLogout()
    }
}
```

`didBecomeActive` / `willResignActive` are protocol default-implementation methods, so there is no `override` and no `super` call. Subscriptions started with `task { }` on the lifecycle are cancelled automatically when the interactor deactivates.

Use `PresentableInteractable` when the interactor communicates with a view through a presentable protocol. Use plain `Interactable` for napkins without views.

### Router

The **Router** is `@MainActor`, manages the napkin tree, owns the interactor, maintains a list of children, and coordinates navigation.

- `attachChild(_:)` `async` — adds a child router, activates its interactor, and loads it
- `detachChild(_:)` `async` — deactivates the child's interactor and removes it
- `didLoad()` `async open` — called once when the router is first loaded; attach permanent children here

Use `Router<InteractorType>` for napkins without views. Use `ViewableRouter<InteractorType, ViewControllerType>` when the napkin has a view controller.

```swift
@MainActor
protocol HomeRouting: ViewableRouting {
    func routeToProfile() async
    func routeBackFromProfile() async
}

@MainActor
final class HomeRouter: ViewableRouter<HomeInteractor, HomeViewControllable>,
                        HomeRouting {

    private let profileBuilder: ProfileBuildable
    private var profileRouter: ProfileRouting?

    init(interactor: HomeInteractor,
         viewController: HomeViewControllable,
         profileBuilder: ProfileBuildable) {
        self.profileBuilder = profileBuilder
        super.init(interactor: interactor, viewController: viewController)
    }

    func routeToProfile() async {
        guard profileRouter == nil else { return }

        let router = await profileBuilder.build(withListener: interactor)
        profileRouter = router
        await attachChild(router)
        viewController.uiviewController.present(
            router.viewControllable.uiviewController,
            animated: true
        )
    }

    func routeBackFromProfile() async {
        guard let router = profileRouter else { return }
        profileRouter = nil

        viewController.uiviewController.dismiss(animated: true)
        await detachChild(router)
    }
}
```

Because the router is already on the main actor, there are no `Task { @MainActor in }` hops. `attachChild` / `detachChild` are `async` and serialize with the interactor's actor when activating / deactivating. The pattern is:

1. Build the child (`async @MainActor` for view-owning napkins)
2. `await attachChild(router)` — activates the interactor on its own actor, loads the router on the main actor
3. Present — manipulates the view hierarchy directly on `@MainActor`

For detaching, the order is reversed: dismiss the view, then `await detachChild(router)`.

### Presenter (Optional)

The **Presenter** transforms business data into view-friendly formats. It sits between the interactor and the view controller. `Presenter` is `@MainActor` and `@Observable`, so SwiftUI views can read its stored properties directly via `@Bindable`:

```swift
protocol HomePresentable: Presentable, Sendable {
    func presentUser(_ user: User) async
}

@MainActor
final class HomePresenter: Presenter<HomeViewControllable>, HomePresentable {

    var displayName: String = ""

    func presentUser(_ user: User) async {
        displayName = "\(user.firstName) \(user.lastName)"
    }
}
```

The interactor calls `await presenter.presentUser(user)` from its actor; the await is the boundary crossing onto the main actor.

In many cases you won't need a separate `Presenter` class. The simpler pattern — used by the included templates — is to make the view controller conform to the feature-specific `Presentable` protocol directly. The interactor declares `nonisolated let presenter: HomePresentable`, calls `await presenter.presentUser(user)` to send data, and the view controller forwards user events back to the interactor via a `PresentableListener` protocol whose methods are `async`.

### ViewControllable

`ViewControllable` is the only `@MainActor`-isolated protocol in napkin. It provides access to the underlying platform view controller:

```swift
// UIKit — UIViewController subclasses conform automatically
final class HomeViewController: UIViewController, HomeViewControllable {
    // uiviewController returns self via default implementation
}

// SwiftUI — use a UIHostingController
final class HomeHostingController: UIHostingController<HomeView>, HomeViewControllable {
    init() {
        super.init(rootView: HomeView())
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
```

Define a feature-specific protocol extending `ViewControllable` for methods the router or presenter needs:

```swift
@MainActor protocol HomeViewControllable: ViewControllable {
    func displayUserName(_ name: String)
}
```

## Routing & Navigation

Routing separates the **logical tree** (attach/detach) from the **visual tree** (present/dismiss). The router is `@MainActor`, so view manipulation runs inline; `attachChild` / `detachChild` are `async` because they activate or deactivate the child interactor on its own actor.

**Modal presentation:**

```swift
func routeToSettings() async {
    guard settingsRouter == nil else { return }

    let router = await settingsBuilder.build(withListener: interactor)
    settingsRouter = router
    await attachChild(router)
    viewController.uiviewController.present(
        router.viewControllable.uiviewController,
        animated: true
    )
}
```

**Push onto a navigation stack:**

```swift
func routeToDetail(id: String) async {
    guard detailRouter == nil else { return }

    let router = await detailBuilder.build(withListener: interactor, id: id)
    detailRouter = router
    await attachChild(router)

    let nav = viewController.uiviewController as! UINavigationController
    nav.pushViewController(
        router.viewControllable.uiviewController,
        animated: true
    )
}
```

**Embed a child view:**

```swift
func attachDashboard() async {
    let router = await dashboardBuilder.build(withListener: interactor)
    dashboardRouter = router
    await attachChild(router)

    let parent = viewController.uiviewController
    let child = router.viewControllable.uiviewController
    parent.addChild(child)
    parent.view.addSubview(child.view)
    child.didMove(toParent: parent)
}
```

**Viewless napkin (no UI):**

```swift
func attachAnalytics() async {
    guard analyticsRouter == nil else { return }
    let router = await analyticsBuilder.build(withListener: interactor)
    analyticsRouter = router
    await attachChild(router)
}
```

## Launching the App

Use `LaunchRouter` as the root of the napkin tree. Its `launch(from:)` method is `async`: it sets the root view controller on the window, activates the interactor, and `await`s `load()`. Hop into a `Task { @MainActor in }` from the synchronous scene callback:

```swift
class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?
    private var launchRouter: LaunchRouting?

    func scene(_ scene: UIScene,
               willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {

        guard let windowScene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: windowScene)
        self.window = window

        let component = AppComponent()
        let builder = RootBuilder(dependency: component)

        Task { @MainActor in
            let router = await builder.build(withListener: AppListener())
            self.launchRouter = router
            await router.launch(from: window)
        }
    }
}
```

The root router subclasses `LaunchRouter`:

```swift
@MainActor
final class RootRouter: LaunchRouter<RootInteractor, RootViewControllable>,
                        RootRouting {

    private let homeBuilder: HomeBuildable

    init(interactor: RootInteractor,
         viewController: RootViewControllable,
         homeBuilder: HomeBuildable) {
        self.homeBuilder = homeBuilder
        super.init(interactor: interactor, viewController: viewController)
    }

    override func didLoad() async {
        await super.didLoad()
        await routeToHome()
    }

    func routeToHome() async {
        let router = await homeBuilder.build(withListener: interactor)
        await attachChild(router)
    }
}
```

## SwiftUI Integration

Wrap SwiftUI views in a `UIHostingController` that conforms to `ViewControllable`. Use `@Observable` (not `ObservableObject`) on the presenter, and `@Bindable` to read it from the view:

```swift
@Observable
@MainActor
final class HomePresenter: Presenter<HomeViewController>, HomePresentable {
    var userName: String = ""
    func presentUser(_ user: User) async {
        userName = "\(user.firstName) \(user.lastName)"
    }
}

struct HomeView: View {
    @Bindable var presenter: HomePresenter
    weak var listener: HomePresentableListener?

    var body: some View {
        VStack {
            Text(presenter.userName)
            Button("Profile") {
                dispatch { await listener?.didTapProfile() }
            }
        }
    }
}

@MainActor protocol HomeViewControllable: ViewControllable {}

@MainActor
final class HomeViewController: UIHostingController<HomeView>,
                                HomeViewControllable {

    init(presenter: HomePresenter) {
        super.init(rootView: HomeView(presenter: presenter))
    }

    @MainActor required dynamic init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
```

The builder creates the presenter and view controller and wires them to the interactor:

```swift
@MainActor
func build(withListener listener: HomeListener) async -> HomeRouting {
    let component = HomeComponent(dependency: dependency)
    let presenter = HomePresenter(viewController: /* placeholder */ HomeViewController(presenter: stub))
    let viewController = HomeViewController(presenter: presenter)
    let interactor = HomeInteractor(presenter: presenter, userService: component.userService)
    await interactor.set(listener: listener)
    let router = HomeRouter(interactor: interactor, viewController: viewController)
    await interactor.set(router: router)
    return router
}
```

Forward user actions to the interactor with `dispatch { await listener?.didTapX() }`. The `dispatch` helper is `@MainActor` and spawns an unstructured `Task` to call the actor-isolated listener — it's the bridge from a synchronous SwiftUI button handler to the async listener method:

```swift
protocol HomePresentableListener: AnyObject, Sendable {
    func didTapProfile() async
}

struct HomeView: View {
    @Bindable var presenter: HomePresenter
    weak var listener: HomePresentableListener?

    var body: some View {
        Button("Profile") {
            dispatch { [listener] in await listener?.didTapProfile() }
        }
    }
}
```

## Testing

napkin uses Swift Testing. Interactor tests are `async`; assertions about actor-isolated state require `await`. Mocks for `Sendable` listener and `@MainActor` presentable protocols can be plain `final class`es with the appropriate isolation:

```swift
import Testing
@testable import YourApp

@Suite("HomeInteractor")
struct HomeInteractorTests {

    @Test func didTapLogout_notifiesListener() async {
        let listener = MockHomeListener()
        let presenter = await MockHomePresentable()
        let interactor = HomeInteractor(presenter: presenter, userService: MockUserService())
        await interactor.set(listener: listener)
        await interactor.activate()

        await interactor.didTapLogout()

        #expect(await listener.logoutCalled)
    }
}

final actor MockHomeListener: HomeListener {
    private(set) var logoutCalled = false
    func homeDidRequestLogout() async { logoutCalled = true }
}

@MainActor
final class MockHomePresentable: HomePresentable {
    weak var listener: HomePresentableListener?
    var lastUser: User?
    func presentUser(_ user: User) async { lastUser = user }
}
```

Run tests via SwiftPM:

```bash
swift test
```

Or via Xcode (Command+U after opening `Package.swift`), or via fastlane:

```bash
bundle install
bundle exec fastlane unit_test
```

### Runnable example app

A minimal iOS app under [`Examples/LaunchNapkinApp`](Examples/) demonstrates the framework end-to-end. It is verified working on iPhone 17 / iOS 26.4 simulator. Requires [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`):

```bash
cd Examples/LaunchNapkinApp
xcodegen
open LaunchNapkinApp.xcodeproj
```

See [`Examples/README.md`](Examples/README.md) for details.

## Tooling

### Xcode Templates

napkin includes Xcode templates for creating napkin components from the **File** > **New File...** menu.

#### Install

```bash
git clone https://github.com/WikipediaBrown/napkin.git
bash napkin/Tools/InstallXcodeTemplates.sh
```

#### Available Templates

| Template | Description |
|----------|-------------|
| **napkin** | Builder, Interactor, Router (+ optional ViewController) |
| **Launch napkin** | Root napkin for app launch |
| **napkin Unit Tests** | Interactor and Router test files |
| **Component Extension** | Component extension for child dependencies |
| **Service Manager** | Service manager pattern |

## Versioning

napkin releases [new versions on GitHub](https://github.com/WikipediaBrown/napkin/releases) automatically when a pull request is merged from `develop` to `main`.

## Contributing

Send a pull request or create an issue. Commits must be signed:

```bash
git config commit.gpgsign true
```

## Author

Wikipedia Brown

## License

napkin is available under the Apache 2.0 license. See the LICENSE file for more info.

<p align="center">Made with cascadian love</p>
