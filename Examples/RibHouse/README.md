# Napkin's Rib House

A runnable iOS app that demonstrates napkin end-to-end through a login/logout flow:

- **LaunchNapkin** (headless, holds an `AuthService`) starts by attaching the **LoggedOutNapkin**.
- **LoggedOutNapkin** shows a single **Login** button. Tapping it sends `loggedOutDidTapLogin()` up to the Launch interactor via the listener pattern.
- The Launch interactor calls `authService.login()`, gets back a `User` ("Smokey Joe" + a list of barbecue foods), and asks its router to swap to **LoggedInNapkin**.
- **LoggedInNapkin** shows the user's name and food list with a **Logout** button. Tapping it reverses the flow.

The companion walkthrough lives in DocC: [`Tutorial: Building a Login Flow`](../../Sources/napkin/napkin.docc/Articles/TutorialBuildingALoginFlow.md).

## Layout

```
Examples/RibHouse/
├── project.yml                     # XcodeGen spec (RibHouse target + UI tests)
├── RibHouse.xcodeproj              # Tracked — opens directly, no codegen needed
├── README.md                       # You are here
├── Sources/
│   ├── App/                        # App shell + dependency root
│   │   ├── AppDelegate.swift
│   │   ├── SceneDelegate.swift     # AppComponent provides AuthService
│   │   └── Info.plist
│   ├── Shared/                     # Cross-napkin types
│   │   ├── AccessibilityIdentifiers.swift
│   │   ├── AuthService.swift       # Protocol + BarbecueAuthService mock
│   │   ├── Palette.swift           # OKLCH-derived design tokens
│   │   └── User.swift              # { name, barbecueFoods }
│   ├── LaunchNapkin/               # Parent — headless container, holds AuthService
│   │   ├── LaunchNapkinBuilder.swift
│   │   ├── LaunchNapkinHostingViewController.swift
│   │   ├── LaunchNapkinInteractor.swift
│   │   └── LaunchNapkinRouter.swift
│   ├── LoggedOutNapkin/            # Child — Login button
│   │   ├── LoggedOutNapkinBuilder.swift
│   │   ├── LoggedOutNapkinHostingViewController.swift
│   │   ├── LoggedOutNapkinInteractor.swift
│   │   ├── LoggedOutNapkinRouter.swift
│   │   └── LoggedOutNapkinView.swift
│   └── LoggedInNapkin/             # Child — User name + food list + Logout
│       ├── LoggedInNapkinBuilder.swift
│       ├── LoggedInNapkinHostingViewController.swift
│       ├── LoggedInNapkinInteractor.swift
│       ├── LoggedInNapkinRouter.swift
│       └── LoggedInNapkinView.swift
└── UITests/
    └── RibHouseUITests.swift       # XCUITest end-to-end
```

## Run it

```bash
open Examples/RibHouse/RibHouse.xcodeproj
```

Then press **⌘R** with an iPhone simulator selected.

## Regenerate the project

The Xcode project is tracked in the repo so the example opens without
running XcodeGen first. If you change `project.yml` or add files outside
the existing folders, regenerate:

```bash
cd Examples/RibHouse
xcodegen
```

## Run the UI tests

```bash
cd Examples/RibHouse
xcodebuild \
  -project RibHouse.xcodeproj \
  -scheme RibHouse \
  -destination "platform=iOS Simulator,name=iPhone 17,OS=latest" \
  test
```
