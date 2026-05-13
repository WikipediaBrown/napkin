# LaunchNapkinApp

A minimal iOS app demonstrating three napkins (Launch, Counter, Quote) and
the framework end-to-end. The Launch napkin is the root; it attaches the
Counter and Quote child napkins and renders a SwiftUI shell that hosts
them. Use this app as the runnable counterpart to the prose walkthroughs
in the [`DefiningAFeature`](../../Sources/napkin/napkin.docc/Articles/DefiningAFeature.md)
DocC article.

## Layout

```
Examples/LaunchNapkinApp/
├── project.yml                 # XcodeGen project spec
├── Sources/                    # App shell + all three napkins (side by side)
│   ├── AppDelegate.swift
│   ├── SceneDelegate.swift
│   ├── Info.plist
│   ├── AccessibilityIdentifiers.swift
│   │
│   ├── LaunchNapkinBuilder.swift               # Launch napkin (root)
│   ├── LaunchNapkinInteractor.swift
│   ├── LaunchNapkinRouter.swift
│   ├── LaunchNapkinView.swift
│   ├── LaunchNapkinHostingViewController.swift
│   │
│   ├── CounterNapkinBuilder.swift              # Counter napkin (child)
│   ├── CounterNapkinInteractor.swift
│   ├── CounterNapkinRouter.swift
│   ├── CounterNapkinView.swift
│   ├── CounterNapkinHostingViewController.swift
│   │
│   ├── QuoteNapkinBuilder.swift                # Quote napkin (child)
│   ├── QuoteNapkinInteractor.swift
│   ├── QuoteNapkinRouter.swift
│   ├── QuoteNapkinView.swift
│   └── QuoteNapkinHostingViewController.swift
│
└── UITests/
    └── LaunchNapkinAppUITests.swift
```

The app shell (`AppDelegate`, `SceneDelegate`, `Info.plist`) and the
napkin implementations live side by side in `Sources/` — this is
intentional after the 2.0.7 consolidation. Keeping them flat makes the
example easier to skim; the file-name prefix (`LaunchNapkin*`,
`CounterNapkin*`, `QuoteNapkin*`) carries the grouping.

## Run

XcodeGen materializes `LaunchNapkinApp.xcodeproj` from `project.yml`:

```sh
brew install xcodegen
cd Examples/LaunchNapkinApp && xcodegen
open LaunchNapkinApp.xcodeproj
```

Select the **LaunchNapkinApp** scheme and press `⌘+R`. Targets an
iPhone 17 / iOS 26 simulator out of the box.

## UI tests

The `LaunchNapkinAppUITests` target exercises the three-napkin tree via
accessibility identifiers exported from `AccessibilityIdentifiers.swift`:

```sh
xcodebuild test \
  -project Examples/LaunchNapkinApp/LaunchNapkinApp.xcodeproj \
  -scheme LaunchNapkinApp \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest'
```

This same invocation runs in the **Example App UI Tests** job in CI
(`.github/workflows/Tests.yml`).

## Companion docs

The DocC catalog ships a [`DefiningAFeature`](../../Sources/napkin/napkin.docc/Articles/DefiningAFeature.md)
article that walks through the napkin pattern with snippets mirroring the
Counter napkin source files in this directory. Read the article alongside
the runnable code to see the same five-file shape (Builder, Interactor,
Router, View, ViewController) twice — once as narrative, once as a
working iOS target.
