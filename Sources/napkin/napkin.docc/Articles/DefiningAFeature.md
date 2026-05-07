# Defining a Feature

Build a single feature, file by file. We'll define a generic `Profile` napkin that displays a user's name and exposes a "Done" button to its parent.

## Overview

This article walks through every file you write to define a viewable napkin. Each section explains *why* the file is shaped the way it is — not just what to type. By the end you will have a complete `Profile` napkin: builder, component, interactor, router, view controller, and SwiftUI view.

## ProfileBuilder.swift

The builder is the only entry point a parent napkin sees. It owns the parent-supplied dependency, creates a ``Component`` for this napkin's own scope, instantiates the interactor and router, wires the listener, and returns the router as the public face of the napkin.

```swift
import napkin

protocol ProfileDependency: Dependency {
    var userService: UserService { get }
}

final class ProfileComponent: Component<ProfileDependency>, @unchecked Sendable {
    // Pass-through services and locally created instances live here.
    var userService: UserService { dependency.userService }
}

protocol ProfileBuildable: Buildable {
    @MainActor func build(withListener listener: ProfileListener) async -> ProfileRouting
}

final class ProfileBuilder:
    Builder<ProfileDependency>,
    ProfileBuildable,
    @unchecked Sendable
{
    override init(dependency: ProfileDependency) {
        super.init(dependency: dependency)
    }

    @MainActor
    func build(withListener listener: ProfileListener) async -> ProfileRouting {
        let component = ProfileComponent(dependency: dependency)
        let viewController = ProfileViewController()
        let interactor = ProfileInteractor(
            presenter: viewController,
            userService: component.userService
        )
        await interactor.set(listener: listener)
        let router = ProfileRouter(interactor: interactor, viewController: viewController)
        await interactor.set(router: router)
        return router
    }
}
```

**Why `async @MainActor`.** The builder constructs view controllers, which are `@MainActor`-isolated. It also calls into the interactor (an actor) to wire the listener and the router. Both crossings require `await`, so the build method itself is `async`.

**Why two-phase wiring.** The interactor needs a router, and the router needs the interactor. We construct the interactor first, hand it to the router, then call `await interactor.set(router: router)`. This breaks the cycle without exposing a mutable property to the outside world; only the builder ever calls `set(router:)`.

## ProfileInteractor.swift

The interactor is a `final actor`. It conforms to ``PresentableInteractable`` and to the listener protocol that its view emits.

```swift
import napkin

@MainActor
protocol ProfileRouting: ViewableRouting, Sendable {
    // Methods the interactor can invoke to drive child routing.
}

protocol ProfilePresentable: Presentable, Sendable {
    @MainActor var listener: ProfilePresentableListener? { get set }
    func update(displayName: String) async
}

protocol ProfileListener: AnyObject, Sendable {
    func profileDidFinish() async
}

final actor ProfileInteractor: PresentableInteractable, ProfilePresentableListener {

    nonisolated let lifecycle = InteractorLifecycle()
    nonisolated let presenter: ProfilePresentable

    weak var router: ProfileRouting?
    weak var listener: ProfileListener?

    private let userService: UserService

    init(presenter: ProfilePresentable, userService: UserService) {
        self.presenter = presenter
        self.userService = userService
    }

    func set(router: ProfileRouting?) { self.router = router }
    func set(listener: ProfileListener?) { self.listener = listener }

    func didBecomeActive() async {
        let user = await userService.currentUser
        await presenter.update(displayName: "\(user.firstName) \(user.lastName)")
        await MainActor.run { presenter.listener = self }
    }

    func willResignActive() async {
        await MainActor.run { presenter.listener = nil }
    }

    // MARK: - ProfilePresentableListener

    func didTapDone() async {
        await listener?.profileDidFinish()
    }
}
```

**Why `final actor`.** Actors give us mutual-exclusion on stored state for free. `final` is required because actors cannot be subclassed (see <doc:ProtocolCompositionOverInheritance>).

**Why `nonisolated let lifecycle`.** ``Interactable`` requires a stored ``InteractorLifecycle``. Marking it `nonisolated` lets the parent router invoke ``Interactable/activate()`` and ``Interactable/deactivate()`` on this actor without first hopping into its executor — which matters because activation is itself the operation that schedules work on the actor.

**Why `weak var listener`.** The listener is the *parent's* interactor. Holding it strongly would create a retain cycle: parent retains child router → child router retains child interactor → child interactor retains parent → cycle.

**Why two `set(...)` methods.** Both `router` and `listener` are stored on the actor, so they can only be assigned by code running on the actor. The builder wires them via `await interactor.set(...)`.

**Why `MainActor.run` for `presenter.listener`.** The presenter is `@MainActor`-isolated. Setting its `listener` property requires being on the main actor. We hop briefly via `MainActor.run` rather than awaiting an async setter for clarity.

## ProfileRouter.swift

The router is `@MainActor`. For a leaf napkin like Profile it does very little; for a feature with children it holds child builders and exposes `routeToX()` methods that the interactor calls.

```swift
import napkin

@MainActor
protocol ProfileViewControllable: ViewControllable {
    // Methods the router invokes on the view, e.g. presenting child VCs.
}

@MainActor
final class ProfileRouter:
    ViewableRouter<ProfileInteractor, ProfileViewControllable>,
    ProfileRouting
{
    override init(
        interactor: ProfileInteractor,
        viewController: ProfileViewControllable
    ) {
        super.init(interactor: interactor, viewController: viewController)
    }
}
```

**Why generic over both interactor and view-controllable type.** ``ViewableRouter`` is `ViewableRouter<InteractorType, ViewControllerType>`. Storing the concrete `ProfileInteractor` lets the router call into the actor with full type information; storing the `ProfileViewControllable` protocol (rather than the concrete `ProfileViewController`) keeps the router decoupled from the view's class.

**Why `@MainActor`.** Routers manipulate the view tree. Every method that pushes, presents, or embeds a view controller has to run on the main actor.

## ProfileViewController.swift

The view controller is a `UIHostingController` (or `NSHostingController`) that wraps the SwiftUI view and conforms to the feature's ``Presentable`` protocol. In this small example the view controller doubles as the presenter — it has no view state worth holding separately.

```swift
import napkin
import SwiftUI

protocol ProfilePresentableListener: AnyObject, Sendable {
    func didTapDone() async
}

#if canImport(UIKit)
@MainActor
final class ProfileViewController:
    UIHostingController<ProfileView>,
    ProfilePresentable
{
    weak var listener: ProfilePresentableListener? {
        didSet { rootView.listener = listener }
    }

    init() {
        super.init(rootView: ProfileView())
    }

    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(displayName: String) async {
        rootView.displayName = displayName
    }
}
#endif

extension ProfileViewController: ProfileViewControllable {}
```

**Why `UIHostingController`.** It is the cheapest path from a SwiftUI `View` to something that conforms to ``ViewControllable``. The `UIKit` extension on `UIViewController` makes any UIKit view controller a ``ViewControllable`` automatically.

**Why a `weak` listener.** Same reasoning as in the interactor: the listener is owned upstream. The view should not retain the actor that retains it.

**Why `func update(displayName:) async`.** The presenter protocol's update methods are `async` because they are called from the interactor's actor — `await presenter.update(...)` from there hops onto the main actor.

## ProfileView.swift

The SwiftUI view is a thin renderer. It reads from props passed in and forwards user events to the listener via ``dispatch(priority:_:)``.

```swift
import SwiftUI
import napkin

struct ProfileView: View {
    var displayName: String = ""
    weak var listener: ProfilePresentableListener?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text(displayName).font(.title)
                Spacer()
            }
            .padding()
            .navigationTitle("Profile")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dispatch { [listener] in await listener?.didTapDone() }
                    }
                }
            }
        }
    }
}
```

**Why `dispatch { ... }`.** SwiftUI button handlers are synchronous and `@MainActor`. The listener is an actor. ``dispatch(priority:_:)`` spawns an unstructured `Task` so the button can return immediately while the work `await`s the actor.

**Why `[listener]` capture.** `listener` is `weak`. We capture by value at the point of the tap so that the dispatched task gets a stable reference (still weak, since the property type is weak — you may also write `[weak listener]` for clarity).

## What you got

Six files. Each has a single, narrow responsibility. The builder is the only thing your parent imports. The interactor is the only thing that holds business state. The view stays a renderer. The router stays a tree manager. The component stays a DI container.

When you need to add a child feature, you do it from the router (`routeToChild()` calls a child builder, `await attachChild(...)`), give the child interactor a listener protocol, and conform the parent interactor to it.

## See Also

- <doc:CrossIsolationPatterns>
- <doc:HeadlessNapkins>
- <doc:SwiftUIIntegration>
