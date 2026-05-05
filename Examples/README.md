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

### What it does

Loads a `LaunchNapkinHostingViewController` (a SwiftUI view wrapped in a `UIHostingController`) at the window root via napkin's `LaunchRouter`. Tap the button to fire a presenter -> listener event into the actor-isolated `LaunchNapkinInteractor`.
