# napkin

# Now Supporting ***SwiftUI***

![Release Workflow](https://github.com/WikipediaBrown/napkin/actions/workflows/Release.yml/badge.svg) 
[![Swift Versions](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FWikipediaBrown%2Fnapkin%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/WikipediaBrown/napkin)
[![Platforms Supported](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2FWikipediaBrown%2Fnapkin%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/WikipediaBrown/napkin)

napkin is a reimagining of Uber's [RIBs](https://github.com/uber/RIBs) with RXSwift replaced by Combine and the Leak Detector removed (you should use [Xcode Instruments](https://stackoverflow.com/a/51947107/5863650) instead). 

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

### Coming Soon!

## 🪛 Tooling

### 🗺️ Get **napkin** Xcode templates
**napkin** comes with sweet templates that let you add all of the components of a napkin (Builder, Interactor, Router & optional ViewController) straight from the `New > File..` menu. To add them:

#### Clone the repository
```git clone https://github.com/WikipediaBrown/napkin.git```

#### Install Xcode Templates
```bash napkin/Tools/InstallXcodeTemplates.sh```

#### Check Xcode
Open an Xcode project and create a new napkin. Let us know if it doesn't work by creating an issue

## 🧪 Test

Run `command+u` in ***Xcode*** to run the unit tests. Test are run automatically for all pull requests. When running tests locally, be sure to be using `iOS 17.2` or later or `macOS 14.5` or later.

### 🏎️ Fastlane Scan

You can also run tests on both `iOS` & `macOS` using [`fastlane`](https://fastlane.tools). This requires installing `fastlane` which in turn requires installing [`Homebrew`](https://brew.sh). With `Homebrew` and `fastlane` installed you can open a terminal and navigate to the `SFSymbolsKit`'s root folder and run the command `fastlane unit_test`. This will run the unit tests for both `iOS` & `macOS` in succession.

## 🐁 Versioning

**napkin** releases a [new version on GitHub](https://github.com/WikipediaBrown/napkin/releases) automatically when a pull request is approved from the `develop` branch to the `main` branch.

## 👩🏽‍💻 Contribute

Send a pull request my dude... or create an issue.

Must sign commits: 
run 
`git config commit.gpgsign true`

from this repository
## ✍🏽 Author

Wikipedia Brown

## 🪪 License

**napkin** is available under the Apache 2.0 license. See the LICENSE file for more info.

<p align="center">Made with 🌲🌲🌲 in Cascadia</p>