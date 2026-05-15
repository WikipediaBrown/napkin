# napkin Examples

## Napkin's Rib House (`RibHouse/`)

A runnable iOS app demonstrating napkin end-to-end with a login/logout flow: a headless `LaunchNapkin` holds an `AuthService`, swapping between a `LoggedOutNapkin` (Login button) and a `LoggedInNapkin` (user name + barbecue list + Logout).

### Requirements

macOS with Xcode 26 or later.

### Run

```sh
open Examples/RibHouse/RibHouse.xcodeproj
```

The `.xcodeproj` is tracked in the repo — no XcodeGen step needed. Build and run on an iOS 26 simulator.

### Source layout

Each napkin lives in its own folder under `Sources/`:

- `App/` — `AppDelegate`, `SceneDelegate` (with `AppComponent` that provides the `AuthService`), `Info.plist`
- `Shared/` — `AuthService`, `User`, `Palette`, `AccessibilityIdentifiers`
- `LaunchNapkin/` — the parent (headless, holds the service)
- `LoggedOutNapkin/` — child that owns the Login button
- `LoggedInNapkin/` — child that shows the user + Logout button

The companion walkthrough is in DocC: [`Tutorial: Building a Login Flow`](https://getnapkin.to/documentation/napkin/tutorialbuildingaloginflow).

### UI tests

`RibHouseUITests` drives the full flow via XCUITest. Every interactive element is tagged with a stable identifier from `Sources/Shared/AccessibilityIdentifiers.swift` (namespaced as `NapkinAccessibility.LoggedOut.*` / `.LoggedIn.*`):

```swift
app.buttons[NapkinAccessibility.LoggedOut.loginButton].tap()
let name = app.staticTexts[NapkinAccessibility.LoggedIn.nameLabel]
XCTAssertEqual(name.label, "Smokey Joe")
```

Run them with:

```sh
xcodebuild -project Examples/RibHouse/RibHouse.xcodeproj \
  -scheme RibHouse \
  -destination "platform=iOS Simulator,name=iPhone 17,OS=latest" \
  test
```

When adding identifiers to a SwiftUI view tree, **don't put `.accessibilityIdentifier(...)` on the parent container** — SwiftUI propagates it to descendants and overrides their own identifiers. Apply it directly to each interactive element (`Text`, `Button`, etc.).

### Regenerating the project

If you add files outside the existing folders or edit `project.yml`, regenerate the Xcode project with [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`):

```sh
cd Examples/RibHouse
xcodegen
```

### iCloud Drive note

If your local clone lives inside an iCloud Drive folder, code signing can fail with `resource fork, Finder information, or similar detritus not allowed`. iCloud reapplies extended attributes faster than `xattr -c` can clear them. Two workarounds:

1. **Build to a path outside iCloud** — pass `-derivedDataPath /tmp/napkin-build` (or any non-synced location) to `xcodebuild`.
2. **Clone the repo to a non-iCloud directory** (e.g. `~/Developer/napkin`).

Cloning outside iCloud is the cleaner long-term fix.
