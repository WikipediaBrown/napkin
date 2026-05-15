# AGENTS.md

Instructions for AI coding agents working in the napkin repository. Follow these conventions and your changes will look like the rest of the codebase. Ignore them and a reviewer will ask you to redo the work.

## What this project is

napkin is a Swift 6.2 framework for clean-architecture iOS / macOS apps. It's a Swift Concurrency rewrite of Uber's [RIBs](https://github.com/uber/RIBs) — actors instead of base classes, `@MainActor` for routing/presentation, `Sendable` for everything that crosses an isolation boundary.

Every feature is a **napkin**: a small unit composed of a fixed set of "rings" — Builder, Component, Interactor, Router, and (when there's a view) Presenter + ViewController. The pattern repeats across the framework; once you've written one napkin you've written all of them.

## Build and test commands

| Task | Command |
|---|---|
| Build the framework | `swift build` |
| Run framework unit tests | `swift test` |
| Run the example app | `open Examples/RibHouse/RibHouse.xcodeproj` (⌘R to launch) |
| Run example UI + snapshot tests | `cd Examples/RibHouse && xcodebuild -project RibHouse.xcodeproj -scheme RibHouse -destination "platform=iOS Simulator,name=iPhone 17,OS=latest" test` |
| Regenerate the example's xcodeproj | `cd Examples/RibHouse && xcodegen` (only needed when you change `project.yml` or add files outside an existing folder) |
| Build DocC locally | `swift package generate-documentation --target napkin` |

CI runs the same commands on a `macos-26` runner with the highest non-beta Xcode 26.x (`grep -v -i beta` glob in workflows). Use the same simulator (`iPhone 17` / iOS 26) when reproducing failures.

## Code conventions

### One napkin per folder

Each napkin's files live together in one folder under a `Sources/` directory (framework or example). Use the napkin's name as the folder name:

```
Examples/RibHouse/Sources/
├── App/                       # AppDelegate, SceneDelegate, AppComponent, Info.plist
├── Shared/                    # Cross-napkin types (services, models, palette)
├── LaunchNapkin/              # Parent napkin
├── LoggedOutNapkin/           # Child
└── LoggedInNapkin/            # Child
```

A complete napkin folder typically contains 5–6 files named `<Napkin><Type>.swift`:

```
SomeNapkin/
├── SomeNapkinBuilder.swift              # Dependency, Component, Builder
├── SomeNapkinInteractor.swift           # Routing/Listener/Presentable protocols + Interactor actor
├── SomeNapkinRouter.swift               # ViewControllable + Router
├── SomeNapkinView.swift                 # SwiftUI view (skip for headless napkins)
└── SomeNapkinHostingViewController.swift # UIHostingController / NSHostingController + PresentableListener
```

Headless napkins (no view of their own — e.g. orchestrators that only embed children) skip the View + HostingViewController and use a plain `UIViewController` instead.

### Isolation: the four rings

| Ring | Isolation | Stored as |
|---|---|---|
| Interactor | `final actor` | `final actor FooInteractor: Interactable, ...` |
| Router | `@MainActor` | `@MainActor final class FooRouter: ViewableRouter<...>` |
| Presenter / ViewController | `@MainActor` | `@MainActor final class FooViewController: UIHostingController<...>` |
| Builder / Component | `Sendable` class | `final class FooBuilder: Builder<...>, ..., @unchecked Sendable` |

The interactor is the **only** business-logic ring and it lives **off the main actor**. Don't make interactors `@MainActor` "for convenience" — that puts business logic on UIKit's executor and violates the architecture's whole reason for existing.

### The two listener protocols

Inside any napkin you'll see two listener protocols. They are *not* the same thing and live in different files:

| Protocol | File | Direction | Purpose |
|---|---|---|---|
| `<Self>NapkinPresentableListener` | `<Self>NapkinHostingViewController.swift` | view → interactor | Forward taps and gestures from SwiftUI to the actor. Methods are named `didTapX()`, `didTypeX(_:)`, etc. |
| `<Self>NapkinListener` | `<Self>NapkinInteractor.swift` | child interactor → parent interactor | Forward business intent up the tree. Methods are named `<self>NapkinDid<verb>()` — e.g. `loggedOutDidTapLogin()`, `counterDidFinish()`. |

The parent interactor conforms to the child's `<Self>NapkinListener` and implements the methods. The router passes the parent interactor as `withListener:` when it builds the child.

### View → interactor: `dispatch { }`, not `Task { }`

SwiftUI button actions are `@MainActor` closures. The interactor is an actor. Bridging from one to the other goes through napkin's `dispatch` helper:

```swift
// CORRECT
Button("Login") {
    dispatch { [listener] in await listener?.didTapLogin() }
}

// WRONG (don't do this)
Button("Login") {
    Task { await listener?.didTapLogin() }
}
```

`dispatch` is intentional about lifetime — it captures the listener weakly and drops the task if the view goes away mid-tap. Inline `Task { }` doesn't.

### Cross-isolation patterns

| Crossing | Pattern |
|---|---|
| Interactor → Presenter (`actor → @MainActor`) | `await presenter.update(...)` |
| Interactor → Router (`actor → @MainActor`) | `await router?.routeToProfile()` |
| View → Interactor (`@MainActor sync → actor`) | `dispatch { await listener?.didTapX() }` |
| Interactor → Listener (parent interactor) | `await listener?.fooDidFinish()` |

If you find yourself making something `@MainActor` to avoid `await`, you've usually broken the architecture. Add the `await` instead.

### Don't subclass actors

Swift actors can't be subclassed ([SE-0306](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0306-actors.md)). napkin uses **protocol composition** instead — `Interactable` is a protocol with a default extension that delegates lifecycle to a shared `InteractorLifecycle` helper. Each napkin's interactor declares:

```swift
final actor FooInteractor: PresentableInteractable, ...listenerConformances... {
    nonisolated let lifecycle = InteractorLifecycle()
    // ... your state and methods ...
}
```

`final` is required. `nonisolated` on `lifecycle` is required. Don't try to write `class FooInteractor: PresentableInteractor<X>` — that base class no longer exists; the `PresentableInteractor.swift` file in the framework that mentions it is documentation, not code.

## File naming + casing

- Swift filenames: `<Napkin><Type>.swift` — e.g. `LoggedOutNapkinBuilder.swift`. Always include `Napkin` in the type name to keep search legible (`grep LoggedOut` returns too much; `grep LoggedOutNapkin` returns just the napkin).
- Test filenames: same convention plus `Tests` — e.g. `LoggedOutNapkinViewSnapshotTests.swift`.
- Folders: PascalCase, no `Napkin` suffix on the folder name itself — `LoggedOutNapkin/`, not `LoggedOutNapkinFolder/`.

## Testing

- **View-level**: snapshot tests using Point-Free's [swift-snapshot-testing](https://github.com/pointfreeco/swift-snapshot-testing). Reference PNGs are committed under `Examples/RibHouse/SnapshotTests/__Snapshots__/`. First run records; subsequent runs verify.
- **UI tests**: XCUITest in `Examples/RibHouse/UITests/`. Use accessibility identifiers from `Sources/Shared/AccessibilityIdentifiers.swift` — never query by text label.
- **Framework unit tests**: in `Tests/napkinTests/`. Drive interactors by calling their methods directly; mock services with simple `final class Mock<protocol-name>: <protocol-name>` types.

## Repository-level conventions

- **Branches**: feature work on `develop`, releases on `main`. Branch off `develop`, PR back to `develop`. Merging develop → main triggers Release → Documentation.
- **Commits**: imperative subject ("Add tab bar tutorial"), short body explaining the *why*. Co-authored trailer for AI assistance is fine.
- **Don't push to `main` directly** — it's protected against force-push and deletion but allows regular pushes. The merge-from-develop-with-`--no-ff` flow is what triggers Release.
- **Example app's `.xcodeproj` is tracked** so it opens without xcodegen. If you change `project.yml` or add a Swift file in a new folder, regenerate (`cd Examples/RibHouse && xcodegen`).

## iCloud Drive trap

If your clone is inside an iCloud Drive folder, you'll see `* 2.swift`, `* 3.swift`, ` 4.xcodeproj` artifacts appear. They're gitignored but SPM and xcodegen still see them on disk and may bake stale references into builds.

**Before committing**, run:

```bash
find /path/to/napkin \( -name "* 2.*" -o -name "* 3.*" \) -not -path "*/.build/*" -print0 | xargs -0 rm -rf
```

Then re-run xcodegen if you regenerated the project recently.

## What's in the source tree

```
napkin/
├── Sources/napkin/                       # The framework
│   ├── *.swift                           # Builder, Component, Router, ViewableRouter, LaunchRouter, Interactor, etc.
│   ├── napkin.docc/                      # DocC catalog (articles, resources, theme)
│   └── DI/                               # Component + dependency primitives
├── Tests/napkinTests/                    # Framework tests (swift test)
├── Snippets/                             # Code samples referenced by DocC articles
├── Examples/
│   ├── README.md
│   └── RibHouse/                         # Runnable example app ("Napkin's Rib House")
├── Tools/
│   ├── site/                             # The marketing site (getnapkin.to)
│   └── napkin/                           # Xcode templates for File > New File
└── .github/workflows/                    # CI: Tests, Release, Documentation, CodeQL, etc.
```

## See also

- [`CONTRIBUTING.md`](CONTRIBUTING.md) — human-facing contribution guide
- [`README.md`](README.md) — what napkin is + a quick API tour
- [DocC site](https://getnapkin.to/documentation/napkin/) — full architecture reference
- [Tutorial: Building a Login Flow](https://getnapkin.to/documentation/napkin/tutorialbuildingaloginflow) — a guided walkthrough of the example app
