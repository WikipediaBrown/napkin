<p align="center">
  <img src="https://raw.githubusercontent.com/WikipediaBrown/napkin/develop/Tools/napkin/napkin.xctemplate/TemplateIcon%402x.png" alt="napkin logo" width="128" height="128">
</p>

# napkin

![Release Workflow](https://github.com/WikipediaBrown/napkin/actions/workflows/Release.yml/badge.svg)
[![Swift Versions](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FWikipediaBrown%2Fnapkin%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/WikipediaBrown/napkin)
[![Platforms Supported](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FWikipediaBrown%2Fnapkin%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/WikipediaBrown/napkin)

napkin is a fork of Uber's [RIBs](https://github.com/uber/RIBs) with RxSwift replaced by Combine. It structures iOS and macOS applications as a tree of modular units using the Router-Interactor-Builder pattern.

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

- iOS 13.0+
- macOS 10.15+

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

napkin is built with Swift 6 strict concurrency. Business logic runs off the main thread. Only view controllers are `@MainActor`.

| Layer | Isolation | Sendable |
|-------|-----------|----------|
| `Interactor` | Non-isolated | `@unchecked Sendable` (lock-protected) |
| `Router` | Non-isolated | `@unchecked Sendable` (lock-protected) |
| `Builder` | Non-isolated | — |
| `Component` | Non-isolated | — (lock-protected `shared()`) |
| `Presenter` | Non-isolated | — |
| **`ViewControllable`** | **`@MainActor`** | — |

`ViewControllable` is the **enforcement boundary**. The compiler requires `@MainActor` context to access any view controller. Everything else — interactors, routers, builders, components — runs on whatever thread the caller is on.

On `ViewableRouter` and `Presenter`, the `viewController` property is `@MainActor`-isolated. To access it from a non-isolated context, use `Task { @MainActor in }`:

```swift
// Inside a router method (non-isolated)
func routeToDetails() {
    guard detailsRouter == nil else { return }

    Task { @MainActor in
        let router = detailsBuilder.build(withListener: interactor)
        detailsRouter = router
        attachChild(router)
        viewController.uiviewController.present(
            router.viewControllable.uiviewController,
            animated: true
        )
    }
}
```

## Core Components

### Builder

The **Builder** constructs a napkin and wires its dependencies. It receives a `Dependency` from its parent and returns a `Router`.

When the napkin has a view, mark `build()` as `@MainActor` because `UIViewController` initialization requires the main thread:

```swift
protocol HomeDependency: Dependency {
    var userService: UserServiceProtocol { get }
}

protocol HomeBuildable: Buildable {
    @MainActor func build(withListener listener: HomeListener) -> HomeRouting
}

final class HomeBuilder: Builder<HomeDependency>, HomeBuildable {

    @MainActor func build(withListener listener: HomeListener) -> HomeRouting {
        let component = HomeComponent(dependency: dependency)
        let viewController = HomeViewController()
        let interactor = HomeInteractor(
            presenter: viewController,
            userService: component.userService
        )
        interactor.listener = listener
        return HomeRouter(interactor: interactor, viewController: viewController)
    }
}
```

For napkins without views, `build()` does not need `@MainActor`:

```swift
protocol AnalyticsBuildable: Buildable {
    func build(withListener listener: AnalyticsListener) -> AnalyticsRouting
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

The **Interactor** contains all business logic. It has a lifecycle driven by its parent router: `didBecomeActive()` when attached, `willResignActive()` when detached.

Interactors communicate:
- **Up** to parent napkins via `weak var listener` (a protocol the parent implements)
- **Down** to navigation via `weak var router` (a routing protocol the router implements)

```swift
protocol HomeListener: AnyObject {
    func homeDidRequestLogout()
}

protocol HomeInteractable: Interactable {
    var router: HomeRouting? { get set }
    var listener: HomeListener? { get set }
}

final class HomeInteractor: PresentableInteractor<HomePresentable>,
                            HomeInteractable,
                            HomePresentableListener {

    weak var router: HomeRouting?
    weak var listener: HomeListener?

    private let userService: UserServiceProtocol
    private var cancellables = Set<AnyCancellable>()

    init(presenter: HomePresentable, userService: UserServiceProtocol) {
        self.userService = userService
        super.init(presenter: presenter)
    }

    override func didBecomeActive() {
        super.didBecomeActive()
        userService.currentUser
            .sink { [weak self] user in
                self?.presenter.presentUser(user)
            }
            .store(in: &cancellables)
    }

    override func willResignActive() {
        super.willResignActive()
        cancellables.removeAll()
    }

    // MARK: - HomePresentableListener

    func didTapProfile() {
        router?.routeToProfile()
    }

    func didTapLogout() {
        listener?.homeDidRequestLogout()
    }
}
```

Use `PresentableInteractor<T>` when the interactor communicates with a view through a presentable protocol. Use plain `Interactor` for napkins without views.

### Router

The **Router** manages the napkin tree. It owns the interactor, maintains a list of children, and coordinates navigation.

- `attachChild(_:)` — adds a child router, activates its interactor, and loads it
- `detachChild(_:)` — deactivates the child's interactor and removes it
- `didLoad()` — called once when the router is first loaded; attach permanent children here

Use `Router<InteractorType>` for napkins without views. Use `ViewableRouter<InteractorType, ViewControllerType>` when the napkin has a view controller.

```swift
protocol HomeRouting: ViewableRouting {
    func routeToProfile()
    func routeBackFromProfile()
}

final class HomeRouter: ViewableRouter<HomeInteractable, HomeViewControllable>,
                        HomeRouting {

    private let profileBuilder: ProfileBuildable
    private var profileRouter: ProfileRouting?

    init(interactor: HomeInteractable,
         viewController: HomeViewControllable,
         profileBuilder: ProfileBuildable) {
        self.profileBuilder = profileBuilder
        super.init(interactor: interactor, viewController: viewController)
        interactor.router = self
    }

    func routeToProfile() {
        guard profileRouter == nil else { return }

        Task { @MainActor in
            let router = profileBuilder.build(withListener: interactor)
            profileRouter = router
            attachChild(router)
            viewController.uiviewController.present(
                router.viewControllable.uiviewController,
                animated: true
            )
        }
    }

    func routeBackFromProfile() {
        guard let router = profileRouter else { return }
        profileRouter = nil

        Task { @MainActor in
            viewController.uiviewController.dismiss(animated: true)
        }
        detachChild(router)
    }
}
```

The `Task { @MainActor in }` block is the boundary crossing: `attachChild` and `detachChild` are thread-safe and non-isolated, but accessing `viewController` or `viewControllable` requires `@MainActor`. The pattern is:

1. Build the child (`@MainActor` if it creates a view controller)
2. Attach — activates the interactor, loads the router
3. Present — manipulates the view hierarchy on `@MainActor`

For detaching, the order is reversed: dismiss the view, then detach the child.

### Presenter (Optional)

The **Presenter** transforms business data into view-friendly formats. It sits between the interactor and the view controller.

The `Presenter<ViewControllerType>` class stores the view controller, but its `viewController` property is `@MainActor`. Use `Task { @MainActor in }` to update the view:

```swift
protocol HomePresentable: Presentable {
    func presentUser(_ user: User)
}

final class HomePresenter: Presenter<HomeViewControllable>, HomePresentable {

    func presentUser(_ user: User) {
        let displayName = "\(user.firstName) \(user.lastName)"
        Task { @MainActor in
            viewController.displayUserName(displayName)
        }
    }
}
```

In many cases you won't need a separate `Presenter` class. The simpler pattern — used by the included templates — is to make the view controller conform to the `Presentable` protocol directly. The interactor uses `PresentableInteractor<MyPresentable>`, where the view controller is the presentable. The interactor calls methods on `presenter` to send data, and the view controller forwards user events back to the interactor via a `PresentableListener` protocol.

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

Routing separates the **logical tree** (attach/detach) from the **visual tree** (present/dismiss).

Attach/detach are non-isolated and manage the napkin tree and interactor lifecycle. Present/dismiss require `@MainActor` because they touch UIKit.

**Modal presentation:**

```swift
func routeToSettings() {
    guard settingsRouter == nil else { return }

    Task { @MainActor in
        let router = settingsBuilder.build(withListener: interactor)
        settingsRouter = router
        attachChild(router)
        viewController.uiviewController.present(
            router.viewControllable.uiviewController,
            animated: true
        )
    }
}
```

**Push onto a navigation stack:**

```swift
func routeToDetail(id: String) {
    guard detailRouter == nil else { return }

    Task { @MainActor in
        let router = detailBuilder.build(withListener: interactor, id: id)
        detailRouter = router
        attachChild(router)

        let nav = viewController.uiviewController as! UINavigationController
        nav.pushViewController(
            router.viewControllable.uiviewController,
            animated: true
        )
    }
}
```

**Embed a child view:**

```swift
func attachDashboard() {
    Task { @MainActor in
        let router = dashboardBuilder.build(withListener: interactor)
        dashboardRouter = router
        attachChild(router)

        let parent = viewController.uiviewController
        let child = router.viewControllable.uiviewController
        parent.addChild(child)
        parent.view.addSubview(child.view)
        child.didMove(toParent: parent)
    }
}
```

**Viewless napkin (no UI):**

```swift
func attachAnalytics() {
    guard analyticsRouter == nil else { return }
    let router = analyticsBuilder.build(withListener: interactor)
    analyticsRouter = router
    attachChild(router)  // No @MainActor needed
}
```

## Launching the App

Use `LaunchRouter` as the root of the napkin tree. Its `launch(from:)` method sets the root view controller on the window and activates the tree:

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
        let router = builder.build()
        self.launchRouter = router

        router.launch(from: window)
    }
}
```

The root router subclasses `LaunchRouter`:

```swift
final class RootRouter: LaunchRouter<RootInteractable, RootViewControllable>,
                        RootRouting {

    private let homeBuilder: HomeBuildable

    init(interactor: RootInteractable,
         viewController: RootViewControllable,
         homeBuilder: HomeBuildable) {
        self.homeBuilder = homeBuilder
        super.init(interactor: interactor, viewController: viewController)
        interactor.router = self
    }

    override func didLoad() {
        super.didLoad()
        routeToHome()
    }

    func routeToHome() {
        Task { @MainActor in
            let router = homeBuilder.build(withListener: interactor)
            attachChild(router)
        }
    }
}
```

## SwiftUI Integration

Wrap SwiftUI views in a `UIHostingController` that conforms to `ViewControllable`:

```swift
struct HomeView: View {
    @ObservedObject var viewModel: HomeViewModel

    var body: some View {
        Text(viewModel.userName)
    }
}

@MainActor protocol HomeViewControllable: ViewControllable {}

final class HomeViewController: UIHostingController<HomeView>,
                                HomeViewControllable {

    init(viewModel: HomeViewModel) {
        super.init(rootView: HomeView(viewModel: viewModel))
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
```

To pass data from the interactor to the SwiftUI view, share an `ObservableObject` view model. The builder creates it and passes it to both the view controller and the interactor:

```swift
@MainActor func build(withListener listener: HomeListener) -> HomeRouting {
    let component = HomeComponent(dependency: dependency)
    let viewModel = HomeViewModel()
    let viewController = HomeViewController(viewModel: viewModel)
    let interactor = HomeInteractor(viewModel: viewModel, userService: component.userService)
    interactor.listener = listener
    return HomeRouter(interactor: interactor, viewController: viewController)
}
```

To forward user actions from SwiftUI back to the interactor, use a listener protocol on the view:

```swift
protocol HomePresentableListener: AnyObject {
    func didTapProfile()
}

struct HomeView: View {
    @ObservedObject var viewModel: HomeViewModel
    weak var listener: HomePresentableListener?

    var body: some View {
        Button("Profile") {
            listener?.didTapProfile()
        }
    }
}
```

## Testing

napkin's non-isolated design makes testing straightforward. No `@MainActor` annotations are needed on test classes or mocks for interactors and routers:

```swift
import Testing
@testable import YourApp

struct HomeInteractorTests {

    @Test func didTapLogout_notifiesListener() {
        let listener = MockHomeListener()
        let presenter = MockHomePresentable()
        let interactor = HomeInteractor(presenter: presenter, userService: MockUserService())
        interactor.listener = listener
        interactor.activate()

        interactor.didTapLogout()

        #expect(listener.logoutCalled)
    }
}

final class MockHomeListener: HomeListener {
    var logoutCalled = false
    func homeDidRequestLogout() { logoutCalled = true }
}

final class MockHomePresentable: HomePresentable {
    var listener: HomePresentableListener?
    var lastUser: User?
    func presentUser(_ user: User) { lastUser = user }
}
```

Run tests with `Command+U` in Xcode, or via fastlane:

```bash
cd napkin
bundle install
bundle exec fastlane unit_test
```

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
