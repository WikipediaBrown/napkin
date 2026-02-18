# napkin

# Now Supporting ***SwiftUI***

![Release Workflow](https://github.com/WikipediaBrown/napkin/actions/workflows/Release.yml/badge.svg)
[![Swift Versions](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FWikipediaBrown%2Fnapkin%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/WikipediaBrown/napkin)
[![Platforms Supported](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FWikipediaBrown%2Fnapkin%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/WikipediaBrown/napkin)

napkin is a reimagining of Uber's [RIBs](https://github.com/uber/RIBs) with RxSwift replaced by Combine. It provides a robust architecture for building scalable iOS applications using the Router-Interactor-Builder pattern.

## Architecture

napkin implements the RIB (Router-Interactor-Builder) architecture pattern:

- **Router**: Manages navigation and child napkin attachment/detachment. Drives the lifecycle of its owned Interactor.
- **Interactor**: Contains business logic. Has an active/inactive lifecycle driven by router attachment.
- **Builder**: Instantiates napkins and wires up dependencies using hierarchical dependency injection.
- **Component**: Defines dependencies a napkin provides to its internal units and child napkins.
- **Presenter** (optional): Translates business models to view models.
- **View** (optional): UI layer, supports both UIKit and SwiftUI.

## Supported Platforms

napkin supports Apple platforms only:
- iOS 13.0+
- macOS (via Mac Catalyst)

## 🛠️ Installation
**napkin** can be installed with Swift Package Manager.

### Swift Package Manager (Xcode 12 or higher)

The preferred way of installing **napkin** is via the [Swift Package Manager](https://swift.org/package-manager/).

1. In Xcode, open your project and navigate to **File** → **Swift Packages** → **Add Package Dependency...**
2. Paste the repository URL (`https://github.com/WikipediaBrown/napkin.git`) and click **Next**.
3. For **Rules**, select **Version (Up to Next Major)** and click **Next**.
4. Click **Finish**.

[Adding Package Dependencies to Your App](https://developer.apple.com/documentation/swift_packages/adding_package_dependencies_to_your_app)


## 👩🏽‍💻 Usage

### Core Components

#### Interactor
The Interactor contains business logic and has an observable lifecycle:

```swift
class MyInteractor: Interactor {
    override func didBecomeActive() {
        super.didBecomeActive()
        // Setup subscriptions and initial state
    }

    override func willResignActive() {
        super.willResignActive()
        // Cleanup resources
    }
}
```

#### Router
The Router manages child napkins and navigation:

```swift
class MyRouter: Router<MyInteractor> {
    override func didLoad() {
        super.didLoad()
        // Attach immutable children here
    }

    func routeToChild() {
        let child = childBuilder.build()
        attachChild(child)
    }
}
```

#### Builder
The Builder creates napkins with their dependencies:

```swift
class MyBuilder: Builder<MyDependency> {
    func build() -> MyRouter {
        let component = MyComponent(dependency: dependency)
        let interactor = MyInteractor()
        return MyRouter(interactor: interactor)
    }
}
```

#### Component
Components provide hierarchical dependency injection:

```swift
class MyComponent: Component<ParentDependency>, ChildDependency {
    var myService: MyService {
        return shared { MyServiceImpl() }
    }
}
```

### SwiftUI Support

napkin supports SwiftUI views through `ViewableRouter`:

```swift
class MyRouter: ViewableRouter<MyInteractor, MyViewController> {
    // Router with view controller support
}
```

## 🪛 Tooling

### 🗺️ Get **napkin** Xcode templates
**napkin** comes with sweet templates that let you add all of the components of a napkin (Builder, Interactor, Router & optional ViewController) straight from the `New > File..` menu. To add them:

#### Clone the repository
```bash
git clone https://github.com/WikipediaBrown/napkin.git
```

#### Install Xcode Templates
```bash
bash napkin/Tools/InstallXcodeTemplates.sh
```

#### Check Xcode
Open an Xcode project and create a new napkin. Let us know if it doesn't work by creating an issue.

## 🧪 Test

Run `command+u` in ***Xcode*** to run the unit tests. Test are run automatically for all pull requests. When running tests locally, be sure to be using `iOS 17.2` or later or `macOS 14.5` or later.

### 🏎️ Fastlane Scan

You can also run tests on both `iOS` & `macOS` using [`fastlane`](https://fastlane.tools). This requires installing `fastlane` which in turn requires installing [`Homebrew`](https://brew.sh). With `Homebrew` and `fastlane` installed you can open a terminal and navigate to the `SFSymbolsKit`'s root folder and run the command `fastlane unit_test`. This will run the unit tests for both `iOS` & `macOS` in succession.

## 🐁 Versioning

**napkin** releases a [new version on GitHub](https://github.com/WikipediaBrown/napkin/releases) automatically when a pull request is approved from the `develop` branch to the `main` branch.

## 👩🏽‍💻 Contribute

Send a pull request my dude... or create an issue.
>>>>>>> main

Must sign commits:
```bash
git config commit.gpgsign true
```
from this repository
## ✍🏽 Author

Wikipedia Brown

## 🪪 License

**napkin** is available under the Apache 2.0 license. See the LICENSE file for more info.

<p align="center">Made with 🌲🌲🌲 in Cascadia</p>
