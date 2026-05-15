# Testing a Napkin

How to unit-test an `actor`-based interactor without booting a simulator: mock the presenter, mock the service, drive lifecycle directly, assert on recorded calls.

@Metadata {
    @PageImage(purpose: icon, source: "napkin-icon", alt: "napkin logo")
    @PageColor(green)
    @TitleHeading("Tutorial")
}

## Overview

`Examples/RibHouse/SnapshotTests/` pins the SwiftUI *views*. This article covers the more interesting half: testing the **business logic** in your interactor actors. The two run in different test targets and exist for different reasons:

@Row {
    @Column {
        **Snapshot tests** assert that the *render* matches a recorded image.
        - Run on iOS simulator (`bundle.unit-test` with a UIKit host)
        - Verify visual regressions
        - Test target: `RibHouseSnapshotTests`
    }
    @Column {
        **Interactor tests** assert that *business logic* fires the right side effects.
        - Run on plain Swift (no simulator)
        - Verify routing, service calls, listener notifications
        - Test target: `napkinTests` or `RibHouseInteractorTests`
    }
}

This article focuses on the second. We'll write tests for `LoggedOutNapkinInteractor` (a leaf, just forwards a tap) and `LaunchNapkinInteractor` (the orchestrator that calls the service and routes).

## Step 1: The mocking pattern

napkin interactors collaborate with three things: a **presenter**, a **router**, and (often) a **listener**. All three are protocols, which is what makes the interactor trivially testable. Replace each protocol with a `final class` that records calls.

```swift
import XCTest
@testable import RibHouse

/// Records every method the interactor calls on it, plus any state
/// the interactor sets through the property.
@MainActor
final class MockLoggedOutNapkinPresentable: LoggedOutNapkinPresentable {
    weak var listener: LoggedOutNapkinPresentableListener?
    var updateCount = 0
}
```

> Note: The presenter is `@MainActor`. The mock that conforms to it must be too. Interactors are `actor`s — they'll `await` into the `@MainActor` mock just like they would into the real `UIHostingController`. No special test-only ceremony required.

For the listener (the side the interactor talks *up* to), the mock records intent calls:

```swift
final class MockLaunchToLoggedOutListener: LoggedOutNapkinListener, @unchecked Sendable {
    // The interactor under test calls these on us. We just count them.
    var loggedOutDidTapLoginCalls = 0
    func loggedOutDidTapLogin() async {
        loggedOutDidTapLoginCalls += 1
    }
}
```

`@unchecked Sendable` because the mock has mutable state (the counter) but is only ever touched from the actor that owns it during the test — the compiler can't prove that, so we mark it manually. In a multi-threaded test you'd want a proper synchronization primitive.

## Step 2: A leaf interactor test

Test `LoggedOutNapkinInteractor.didTapLogin()`: when the view (or test) calls it, the interactor should turn around and call `listener?.loggedOutDidTapLogin()` exactly once.

```swift
@MainActor
final class LoggedOutNapkinInteractorTests: XCTestCase {

    func testDidTapLogin_forwardsToListener() async {
        // Arrange
        let presenter = MockLoggedOutNapkinPresentable()
        let listener = MockLaunchToLoggedOutListener()
        let sut = LoggedOutNapkinInteractor(presenter: presenter)
        await sut.set(listener: listener)

        // Act
        await sut.didTapLogin()

        // Assert
        XCTAssertEqual(listener.loggedOutDidTapLoginCalls, 1)
    }
}
```

Three things to notice:

1. **The actor's methods are `async`.** We `await` them from the `@MainActor` test method. Swift Testing or XCTest both support this — no need for `XCTestExpectation`.
2. **No view in sight.** The view (and the SwiftUI tree it lives in) is irrelevant to whether the interactor forwards the tap. That's exactly the point of having an actor with a Presentable protocol — you can test business logic without rendering anything.
3. **No router.** The leaf interactor's job is to forward the intent; routing is the parent's responsibility. We don't even need to mock the router for this test.

> Tip: Name your tests `test<Method>_<expectedBehavior>`. The first half tells the reader *what* you're calling; the second half tells them *what should happen*. The whole name should read like a sentence.

## Step 3: An orchestrator test (the router pattern)

`LaunchNapkinInteractor.loggedOutDidTapLogin()` does more: it calls `authService.login()`, then asks the router to attach the LoggedIn napkin with the returned user. Two collaborators to mock.

### Mock the service

```swift
final class MockAuthService: AuthService, @unchecked Sendable {
    var loginResult: Result<User, Error> = .success(.init(name: "Test User", barbecueFoods: []))
    var loginCalls = 0
    var logoutCalls = 0

    func login() async throws -> User {
        loginCalls += 1
        return try loginResult.get()
    }
    func logout() async throws {
        logoutCalls += 1
    }
}
```

A `Result`-based stub lets you switch the test between the happy path (`.success`) and a failure path (`.failure(SomeError.network)`) without rewriting the mock.

### Mock the router

The router is `@MainActor` and conforms to `LaunchNapkinRouting`. Same pattern:

```swift
@MainActor
final class MockLaunchNapkinRouting: LaunchNapkinRouting {
    var attachLoggedOutCalls = 0
    var attachLoggedInCalls = [(user: User, count: Int)]()

    func attachLoggedOut() async { attachLoggedOutCalls += 1 }
    func attachLoggedIn(user: User) async {
        attachLoggedInCalls.append((user, attachLoggedInCalls.count + 1))
    }

    // LaunchRouting requirements (children, attachChild/detachChild/load) — stub them out
    // or inherit a no-op base if you have one.
    var children: [Routing] { [] }
    func load() async {}
    nonisolated var interactable: Interactable {
        fatalError("not exercised in this test")
    }
}
```

> Important: Conforming to `LaunchRouting` and its parents (`Routing`) means stubbing a few inherited members. For most interactor tests, this boilerplate is a one-time cost — extract it into a `BaseMockRouter` if you find yourself writing it in more than two test files.

### The test

```swift
@MainActor
final class LaunchNapkinInteractorTests: XCTestCase {

    func testLoggedOutDidTapLogin_callsServiceAndAttachesLoggedIn() async throws {
        // Arrange
        let auth = MockAuthService()
        let user = User(name: "Smokey Joe", barbecueFoods: ["Brisket", "Ribs"])
        auth.loginResult = .success(user)
        let router = MockLaunchNapkinRouting()
        let sut = LaunchNapkinInteractor(authService: auth)
        await sut.set(router: router)

        // Act
        await sut.loggedOutDidTapLogin()

        // Assert
        XCTAssertEqual(auth.loginCalls, 1)
        XCTAssertEqual(router.attachLoggedInCalls.count, 1)
        XCTAssertEqual(router.attachLoggedInCalls.first?.user, user)
        XCTAssertEqual(router.attachLoggedOutCalls, 0)
    }

    func testLoggedOutDidTapLogin_onLoginFailure_doesNotAttachLoggedIn() async {
        // Arrange
        let auth = MockAuthService()
        auth.loginResult = .failure(MockError.unauthorized)
        let router = MockLaunchNapkinRouting()
        let sut = LaunchNapkinInteractor(authService: auth)
        await sut.set(router: router)

        // Act
        await sut.loggedOutDidTapLogin()

        // Assert
        XCTAssertEqual(auth.loginCalls, 1)
        XCTAssertEqual(router.attachLoggedInCalls.count, 0)
        // We're still on the logged-out screen because the router was never asked to swap.
    }

    private enum MockError: Error { case unauthorized }
}
```

Two scenarios from one mock. The interactor's logic — "on login error, stay on the logged-out screen" — is now pinned in the test suite. If a future change makes the interactor *also* attach an error-state napkin, that test would need to assert against a new branch. Failure modes become first-class.

## Step 4: Testing lifecycle

`didBecomeActive` is the napkin's `viewDidLoad`. Test it like any other method — it's just an `async` function on the actor.

```swift
@MainActor
final class LaunchNapkinInteractor_LifecycleTests: XCTestCase {

    func testDidBecomeActive_attachesLoggedOut() async {
        let auth = MockAuthService()
        let router = MockLaunchNapkinRouting()
        let sut = LaunchNapkinInteractor(authService: auth)
        await sut.set(router: router)

        await sut.didBecomeActive()

        XCTAssertEqual(router.attachLoggedOutCalls, 1)
    }
}
```

The framework's `Interactable` extension also exposes `activate()` and `deactivate()` if you want to drive the actor through its full lifecycle (which fires `didBecomeActive` / `willResignActive` as side effects). For most tests, calling the lifecycle method directly is more legible.

> Experiment: Try writing a test that activates *twice* in a row and asserts `attachLoggedOutCalls` is still 1 (the framework guards against double-activate). It's a one-line addition to the existing test and proves the invariant is real.

## Step 5: Wiring up a test target

In a SwiftPM library, tests go in `Tests/napkinTests/` and run via `swift test`. For the example app, add a `bundle.unit-test` target to `Examples/RibHouse/project.yml` similar to the snapshot target:

```yaml
RibHouseInteractorTests:
  type: bundle.unit-test
  platform: iOS
  sources:
    - path: InteractorTests
  dependencies:
    - target: RibHouse
  settings:
    base:
      IPHONEOS_DEPLOYMENT_TARGET: "26.0"
      SWIFT_VERSION: "6.2"
      TEST_HOST: "$(BUILT_PRODUCTS_DIR)/RibHouse.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/RibHouse"
      BUNDLE_LOADER: "$(TEST_HOST)"
```

Then regenerate (`xcodegen`) and the tests show up in Xcode's Test navigator and run via `xcodebuild test`.

## Common patterns

**Avoid the temptation to make interactors `@MainActor` "for testability."** It hurts the architecture and doesn't help — `actor` methods are already trivially `async`-testable. Going `@MainActor` would force every test to be `@MainActor` (often awkward when you'd rather not block the main scheduler).

**Don't mock `final actor` types.** You can't subclass them anyway. Inject collaborators by protocol (which is the napkin pattern by default) and mock those.

**Don't assert on the order of `await`s.** Two `await`s in an actor method are sequential by definition; the actor's serial executor enforces it. Asserting "first the service was called, *then* the router was attached" is testing the language, not your code. Assert on observable state ("the router has exactly one attach call").

**Test the interactor's contract, not its internals.** If you find yourself needing to peek at a private property, the test is probably checking the wrong thing. The contract is *"calling X causes Y to happen"* — that's all the test should verify.

## Topics

### Related

@Links(visualStyle: detailedGrid) {
    - <doc:CrossIsolationPatterns>
    - <doc:DefiningAFeature>
    - <doc:TutorialBuildingALoginFlow>
}
