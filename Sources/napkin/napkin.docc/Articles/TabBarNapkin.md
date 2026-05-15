# Tab Bar Napkin

A different routing pattern than the swap demo. A parent napkin attaches multiple children *concurrently*, hosted side-by-side in a `UITabBarController`. Only one is visible at a time, but all stay active.

@Metadata {
    @PageImage(purpose: icon, source: "napkin-icon", alt: "napkin logo")
    @PageColor(green)
    @TitleHeading("Tutorial")
}

## Overview

Most napkin examples show **swap routing**: one child active at a time, detach-then-attach when state changes (e.g. `LoggedOutNapkin` ↔ `LoggedInNapkin` in <doc:TutorialBuildingALoginFlow>). Tab bars need a different pattern: **concurrent routing**, where multiple children are attached at the same time and the parent controls which is *visible*.

```
TabBarNapkin (parent, owns UITabBarController)
├── HomeNapkin       ← all three attached concurrently
├── BrowseNapkin     ←
└── ProfileNapkin    ← only one visible at a time
```

The interactor never detaches a child when the user switches tabs — they all stay active, with their own state, ready to be brought to the front instantly. Only the *view controller* (the `UITabBarController`) cares which one is on screen.

> Note: Compare this to a `UINavigationController` push, which is a third pattern: children are attached *one at a time on top of each other*, and the parent's stack is the source of truth for navigation. napkin's routing primitives support all three; the pattern lives in the router, not in the framework.

## Step 1: The shape

A `TabBarNapkin` has the same six-file shape as any other parent napkin, but with three differences:

@Row {
    @Column {
        **The router holds N child routers**, one per tab. None of them are optional — they're all populated at build time.
    }
    @Column {
        **The view controller is a `UITabBarController` subclass** that exposes a method for the router to install the children's view controllers.
    }
}

Let's build the pieces.

### Dependency + Component + Builder

Standard shape. The dependency declares whatever services the tab bar's interactor and any children need:

```swift
protocol TabBarNapkinDependency: Dependency {
    var authService: AuthService { get }
    // ...any other shared services
}

final class TabBarNapkinComponent: Component<TabBarNapkinDependency>, @unchecked Sendable {
    var authService: AuthService { dependency.authService }
}

// Conform to each child's dependency protocol so we can pass `component` as `dependency:`.
extension TabBarNapkinComponent:
    HomeNapkinDependency, BrowseNapkinDependency, ProfileNapkinDependency {}
```

The builder constructs every child up-front:

```swift
final class TabBarNapkinBuilder: Builder<TabBarNapkinDependency>, TabBarNapkinBuildable, @unchecked Sendable {
    @MainActor
    func build(withListener listener: TabBarNapkinListener) async -> TabBarNapkinRouting {
        let component = TabBarNapkinComponent(dependency: dependency)
        let homeBuilder = HomeNapkinBuilder(dependency: component)
        let browseBuilder = BrowseNapkinBuilder(dependency: component)
        let profileBuilder = ProfileNapkinBuilder(dependency: component)

        let viewController = TabBarNapkinViewController()
        let interactor = TabBarNapkinInteractor()
        await interactor.set(listener: listener)
        let router = TabBarNapkinRouter(
            interactor: interactor,
            viewController: viewController,
            homeBuilder: homeBuilder,
            browseBuilder: browseBuilder,
            profileBuilder: profileBuilder
        )
        await interactor.set(router: router)
        return router
    }
}
```

## Step 2: The router

This is where the pattern diverges most from the swap demo. The router builds and attaches *all* children when it loads, then never detaches them until the napkin itself is torn down.

```swift
@MainActor
protocol TabBarNapkinViewControllable: ViewControllable {
    func installTabs(_ children: [ViewControllable])
}

@MainActor
final class TabBarNapkinRouter:
    ViewableRouter<TabBarNapkinInteractor, TabBarNapkinViewControllable>,
    TabBarNapkinRouting
{
    private let homeBuilder: HomeNapkinBuildable
    private let browseBuilder: BrowseNapkinBuildable
    private let profileBuilder: ProfileNapkinBuildable

    private var homeRouter: HomeNapkinRouting?
    private var browseRouter: BrowseNapkinRouting?
    private var profileRouter: ProfileNapkinRouting?

    init(
        interactor: TabBarNapkinInteractor,
        viewController: TabBarNapkinViewControllable,
        homeBuilder: HomeNapkinBuildable,
        browseBuilder: BrowseNapkinBuildable,
        profileBuilder: ProfileNapkinBuildable
    ) {
        self.homeBuilder = homeBuilder
        self.browseBuilder = browseBuilder
        self.profileBuilder = profileBuilder
        super.init(interactor: interactor, viewController: viewController)
    }

    // Override the framework's load() to build + attach every child once.
    override func didLoad() async {
        await super.didLoad()
        let home = await homeBuilder.build(withListener: interactor)
        let browse = await browseBuilder.build(withListener: interactor)
        let profile = await profileBuilder.build(withListener: interactor)
        self.homeRouter = home
        self.browseRouter = browse
        self.profileRouter = profile
        await attachChild(home)
        await attachChild(browse)
        await attachChild(profile)
        viewController.installTabs([
            home.viewControllable,
            browse.viewControllable,
            profile.viewControllable,
        ])
    }
}
```

> Important: All three children are `attachChild`-ed which means all three have their `didBecomeActive` fired. That's the *point* of the tab bar pattern — each child stays live (its state persists) when the user is on a different tab.

## Step 3: The view controller

A thin wrapper around `UITabBarController`:

```swift
#if canImport(UIKit)
import UIKit

@MainActor
final class TabBarNapkinViewController: UITabBarController, TabBarNapkinViewControllable {

    func installTabs(_ children: [ViewControllable]) {
        let vcs = children.map { $0.uiviewController }
        // Optional: configure tabBarItem on each (icon, title) here or in the
        // children's own ViewControllers via override init.
        setViewControllers(vcs, animated: false)
    }
}
#elseif canImport(AppKit)
// AppKit has no direct UITabBarController equivalent; for macOS use NSTabViewController.
#endif
```

That's the entire visible UI of the parent napkin — `UITabBarController` handles tab selection, the tab bar itself, the per-child navigation chrome, and the swap-on-tap. The parent's `Interactor` doesn't need to know which tab is currently visible unless its business logic depends on it.

## Step 4: When the interactor *does* care about selection

For pure tab-switching, the interactor is a no-op. But sometimes you want analytics, deep-link routing, or business logic tied to the active tab. The pattern:

1. The view controller becomes the tab bar's `delegate` and forwards selections to a presenter listener.
2. The interactor conforms to that listener and updates state.

```swift
@MainActor
final class TabBarNapkinViewController: UITabBarController, ..., UITabBarControllerDelegate {
    weak var listener: TabBarNapkinPresentableListener?

    override func viewDidLoad() {
        super.viewDidLoad()
        delegate = self
    }

    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        let index = tabBarController.selectedIndex
        dispatch { [listener] in await listener?.didSelectTab(at: index) }
    }
}
```

```swift
protocol TabBarNapkinPresentableListener: AnyObject, Sendable {
    func didSelectTab(at index: Int) async
}

final actor TabBarNapkinInteractor: PresentableInteractable, ..., TabBarNapkinPresentableListener {
    private var selectedIndex: Int = 0

    func didSelectTab(at index: Int) async {
        selectedIndex = index
        // Fire analytics, update routing state, etc.
    }
}
```

> Tip: The selected tab is *view state*. Don't store it in the interactor unless your *business logic* needs it. If you only need it for analytics, fire the event from the view controller's delegate method directly and skip the round-trip through the actor.

## Step 5: Wiring children that need to talk back

Each child napkin has its own `<Self>NapkinListener` protocol that the parent's interactor implements. Just like the swap demo:

```swift
protocol HomeNapkinListener: AnyObject, Sendable {
    func homeDidRequestProfile() async
}

final actor TabBarNapkinInteractor: ..., HomeNapkinListener, BrowseNapkinListener, ProfileNapkinListener {
    // The Home tab can ask the tab bar to switch to the Profile tab.
    func homeDidRequestProfile() async {
        await router?.selectTab(.profile)  // expose this method on TabBarNapkinRouting
    }
}
```

This is how children **influence** parent state without **owning** it. Same listener pattern, same actor isolation, just more siblings.

## Comparison: swap vs tab bar

@Row {
    @Column {
        **Swap routing** (LoggedOut ↔ LoggedIn)
        - One child attached at a time
        - Detach before attach
        - Child state dies on swap
        - Use when only one mode is valid (auth gate)
    }
    @Column {
        **Tab bar routing** (Home + Browse + Profile)
        - All children attached concurrently
        - No detach during tab switching
        - Each tab's state persists
        - Use when the user moves between equally-valid views
    }
}

The framework supports both with the same primitives — `attachChild` / `detachChild` from ``Router``, and your napkin's choice of when to call them. The Router is the only ring that has to know about the difference.

## Topics

### Related

@Links(visualStyle: detailedGrid) {
    - <doc:TutorialBuildingALoginFlow>
    - <doc:HeadlessNapkins>
    - <doc:TestingANapkin>
}
