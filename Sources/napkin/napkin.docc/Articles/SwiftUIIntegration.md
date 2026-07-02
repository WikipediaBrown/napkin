# SwiftUI Integration

How `@Observable` presenters consume state without Combine, the `Observations { ... }` pattern for UIKit, why view events dispatch into a `Task`, and the accessibility-identifier gotcha.

## Overview

napkin doesn't import Combine. The interactor → presenter path uses `async` methods; the presenter → view path uses Observation (the `@Observable` macro). This article explains the consuming patterns for SwiftUI and UIKit, and the small set of pitfalls that have bitten people.

## `@Observable` Presenter + `@Bindable` View

When a feature is large enough to want a dedicated presenter object, subclass ``Presenter`` and add stored properties for view state. ``Presenter`` is `@Observable`, so SwiftUI sees mutations automatically. Subclasses re-annotate `@Observable` so their own stored properties are tracked too.

```swift
import napkin
import SwiftUI

protocol HomePresentable: Presentable, Sendable {
    func presentUser(_ user: User) async
    func presentLogoutFailure(_ message: String) async
}

@MainActor
@Observable
final class HomePresenter: Presenter<HomeViewController>, HomePresentable {

    var displayName: String = ""
    var isLoggingOut: Bool = false
    var errorMessage: String?

    func presentUser(_ user: User) async {
        displayName = "\(user.firstName) \(user.lastName)"
    }

    func presentLogoutFailure(_ message: String) async {
        errorMessage = message
        isLoggingOut = false
    }
}
```

The SwiftUI view receives the presenter as a `@Bindable` and reads stored properties directly. SwiftUI invalidates only the parts of the view that read mutated properties.

```swift
struct HomeView: View {
    weak var presenter: HomePresenter?
    weak var listener: HomeViewListener?

    var body: some View {
        VStack {
            Text(presenter?.displayName ?? "")
            if let error = presenter?.errorMessage {
                Text(error).foregroundStyle(.red)
            }
            Button("Logout") {
                dispatch { [listener] in await listener?.didTapLogout() }
            }
            .disabled(presenter?.isLoggingOut ?? false)
        }
    }
}
```

**Why `@Bindable` and not `@ObservedObject`.** `@Observable` types are not `ObservableObject`. Use `@Bindable` for two-way bindings (`$presenter.foo`) or read directly via `presenter.foo`. There is no `.environmentObject` plumbing — the presenter is just passed in as a property.

**Why `@MainActor` on the presenter.** SwiftUI reads from `@Observable` synchronously during `body` evaluation. The presenter's storage must be readable on the main actor. Marking the class `@MainActor` makes that guarantee explicit.

## `Observations { ... }` for UIKit

If your view layer is UIKit (not SwiftUI inside a hosting controller), use Observation's `Observations { ... }` macro to subscribe to presenter mutations. It re-runs its body whenever any read property changes.

```swift
@MainActor
final class HomeViewController: UIViewController, HomeViewControllable {

    var presenter: HomePresenter!

    @IBOutlet var nameLabel: UILabel!
    @IBOutlet var logoutButton: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()

        Observations {
            self.nameLabel.text = self.presenter.displayName
            self.logoutButton.isEnabled = !self.presenter.isLoggingOut
        }
    }
}
```

**Why `Observations` and not Combine `.sink`.** napkin doesn't depend on Combine. `Observations { ... }` is the Observation framework's first-party "watch these reads" primitive — the same mechanism SwiftUI uses internally. It's lighter, it doesn't require manual cancellation, and it composes with `@Observable` types out of the box.

## View Events Dispatch into a `Task`

SwiftUI button handlers and UIKit `@objc` actions are synchronous. The interactor (the listener) is an actor, so its methods are `async`. The bridge is ``dispatch(priority:_:)``:

```swift
Button("Logout") {
    dispatch { [listener] in await listener?.didTapLogout() }
}
```

In UIKit:

```swift
@objc private func logoutButtonTapped() {
    dispatch { [weak self] in await self?.presenter?.listener?.didTapLogout() }
}
```

**Why `dispatch` rather than making the handler async.** SwiftUI's `Button` has `init(action: () -> Void)`. There is no async overload that fires-and-forgets. UIKit `@objc` actions must be synchronous by definition. ``dispatch(priority:_:)`` is the named wrapper around `Task { ... }` that means "forward this view event into actor-land and let the view return immediately."

**Why `[listener]` capture.** The closure outlives the calling stack. Capturing `listener` by value (it's already a `weak var` on the view) gives the dispatched task a stable reference; if the actor went away mid-dispatch, the call is a no-op.

## The Accessibility Identifier Gotcha

When you place `.accessibilityIdentifier(...)` on a parent view, SwiftUI propagates it to every descendant that doesn't already declare its own. Concretely, if a parent says:

```swift
NavigationStack {
    VStack {
        Button("Increment") { ... }
        Button("Decrement") { ... }
    }
}
.accessibilityIdentifier("HomeScreen")
```

Both buttons will report `accessibilityIdentifier == "HomeScreen"` to the UI test harness, and your tests will fail to disambiguate them.

**The rule:** apply identifiers at the *leaf* level — on the buttons, text fields, and labels themselves — not on their containers.

```swift
HStack {
    Button("-") { ... }
        .accessibilityIdentifier("counter.decrement")
    Button("+") { ... }
        .accessibilityIdentifier("counter.increment")
}
```

This matches the example app's convention (see `Examples/RibHouse/Sources/Shared/AccessibilityIdentifiers.swift`): identifiers are leaf-level, namespaced by feature, and centralized in a single enum so view code and UI tests share a single source of truth.

## Cross-references

- ``Presenter`` — the `@Observable` base for view-state holders.
- ``Presentable`` — the `@MainActor` marker protocol.
- ``ViewControllable`` — the ``Routing``-side view-controller protocol.
- ``dispatch(priority:_:)`` — the `@MainActor`-to-`Task` bridge.

## See Also

- <doc:DefiningAFeature>
- <doc:CrossIsolationPatterns>
