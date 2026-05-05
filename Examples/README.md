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

Loads a `LaunchNapkinHostingViewController` (a SwiftUI view wrapped in a `UIHostingController`) at the window root via napkin's `LaunchRouter`. Tap the button to fire a presenter -> listener event into the actor-isolated `LaunchNapkinInteractor`.

### iCloud Drive note

If your local clone lives inside an iCloud Drive folder, code signing the simulator build can fail with `resource fork, Finder information, or similar detritus not allowed`. iCloud reapplies extended attributes faster than `xattr -c` can clear them. Two workarounds:

1. **Build to a path outside iCloud** — pass `-derivedDataPath /tmp/napkin-build` (or any non-synced location) to `xcodebuild`, or set the project's build location preference in Xcode to `Custom > Relative to Workspace` pointing at a local-only directory.
2. **Clone the repo to a non-iCloud directory** (e.g. `~/Developer/napkin`).

Cloning outside iCloud is the cleaner long-term fix.
