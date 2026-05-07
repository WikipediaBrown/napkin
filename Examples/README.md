# napkin Examples

## LaunchNapkinApp

A minimal iOS app demonstrating the napkin framework end-to-end.

### Requirements

- macOS with Xcode 26 or later
- [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`

### Run

```sh
cd Examples/LaunchNapkinApp
xcodegen
open LaunchNapkinApp.xcodeproj
```

Then build and run on an iOS 26 simulator.

Verified working on iPhone 17 / iOS 26.4.1 simulator: app launches, the `LaunchRouter` activates the actor-isolated interactor, and the SwiftUI view renders without any Swift 6 isolation or sendable warnings.

### What it does

Loads a `LaunchNapkinHostingViewController` (a SwiftUI view wrapped in a `UIHostingController`) at the window root via napkin's `LaunchRouter`. The launch screen presents two child napkins modally — a `CounterNapkin` (demonstrates `@Observable` presenter state and listener-driven dismissal) and a `QuoteNapkin` (demonstrates simpler napkin shape and another listener callback). Together the three napkins exercise the full builder/component/interactor/router/presenter/view stack with actor isolation across the boundary.

### UI tests

The `LaunchNapkinAppUITests` target shows how to write XCUITest tests against an app built with napkin. Every interactive element is tagged with a stable identifier from the shared `AccessibilityIdentifiers.swift` file (namespaced as `NapkinAccessibility.Launch.*`, `.Counter.*`, `.Quote.*`), so tests can refer to elements by symbolic name instead of fragile label strings:

```swift
app.buttons[NapkinAccessibility.Launch.showCounterButton].tap()
app.buttons[NapkinAccessibility.Counter.incrementButton].tap()
let count = app.staticTexts[NapkinAccessibility.Counter.countLabel]
XCTAssertEqual(count.label, "1")
```

Run them with:

```sh
xcodebuild -project Examples/LaunchNapkinApp/LaunchNapkinApp.xcodeproj \
  -scheme LaunchNapkinApp \
  -destination "platform=iOS Simulator,name=iPhone 17,OS=latest" \
  test
```

Important: when adding identifiers to a SwiftUI view tree, **don't put `.accessibilityIdentifier(...)` on the parent container** — SwiftUI propagates it to descendants and overrides their own identifiers. Apply it directly to each interactive element (`Text`, `Button`, etc.).

### iCloud Drive note

If your local clone lives inside an iCloud Drive folder, code signing the simulator build can fail with `resource fork, Finder information, or similar detritus not allowed`. iCloud reapplies extended attributes faster than `xattr -c` can clear them. Two workarounds:

1. **Build to a path outside iCloud** — pass `-derivedDataPath /tmp/napkin-build` (or any non-synced location) to `xcodebuild`, or set the project's build location preference in Xcode to `Custom > Relative to Workspace` pointing at a local-only directory.
2. **Clone the repo to a non-iCloud directory** (e.g. `~/Developer/napkin`).

Cloning outside iCloud is the cleaner long-term fix.
