# Adding a Networked Service

Replace the example app's mock `BarbecueAuthService` with a real `URLSession`-backed implementation. The point: the napkin tree above the service doesn't change.

@Metadata {
    @PageImage(purpose: icon, source: "napkin-icon", alt: "napkin logo")
    @PageColor(green)
    @TitleHeading("Tutorial")
}

## Overview

The example app's `LaunchNapkin` doesn't depend on a service implementation — it depends on a *protocol*:

```swift
protocol LaunchNapkinDependency: Dependency {
    var authService: AuthService { get }
}
```

That decoupling is what makes the auth flow swappable. The shipped example wires in a `BarbecueAuthService` mock that returns Smokey Joe synchronously. A real app would swap it for a `URLSessionAuthService` that talks to a server. Nothing else in the napkin tree changes — same dependency, same builder, same interactor, same listener calls.

This article walks the swap, line by line.

## Step 1: The contract

The interactor only knows the protocol. As long as your concrete impl matches the shape, it slots in:

```swift
protocol AuthService: Sendable {
    func login() async throws -> User
    func logout() async throws
}
```

Three things to internalize:

@Row {
    @Column {
        **`Sendable`** — the service is held by an `actor` (`LaunchNapkinInteractor`) and called from anywhere. The conformance is the compiler's guarantee that crossing the actor boundary is safe.
    }
    @Column {
        **`async`** — `URLSession` is naturally async. The protocol already accommodates a real implementation; the mock just doesn't *need* to suspend.
    }
}

`throws` lets the implementation surface errors without inventing a result type. The interactor's `try await authService.login()` already handles both throw and return cases.

> Tip: Keep `AuthService` in `Sources/Shared/` (or your equivalent). It's not the LaunchNapkin's contract — it's the contract every napkin in the tree could potentially consume. (LoggedInNapkin already declares it in its `Dependency` protocol, even though it doesn't currently call it.)

## Step 2: A concrete `URLSessionAuthService`

Replace the mock with a class that performs real I/O. The implementation lives next to the protocol; the rest of the tree stays untouched.

```swift
import Foundation

/// Production AuthService — talks to the smokehouse's REST API.
///
/// Sendable because every property is `let` and `URLSession` is `Sendable`
/// (it's a reference type whose underlying queue is internally synchronized).
final class URLSessionAuthService: AuthService {
    private let session: URLSession
    private let baseURL: URL
    private let decoder = JSONDecoder()

    init(session: URLSession = .shared, baseURL: URL) {
        self.session = session
        self.baseURL = baseURL
    }

    func login() async throws -> User {
        var request = URLRequest(url: baseURL.appendingPathComponent("login"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        try Self.assertSuccess(response)

        let payload = try decoder.decode(UserPayload.self, from: data)
        return User(name: payload.name, barbecueFoods: payload.foods)
    }

    func logout() async throws {
        var request = URLRequest(url: baseURL.appendingPathComponent("logout"))
        request.httpMethod = "POST"
        let (_, response) = try await session.data(for: request)
        try Self.assertSuccess(response)
    }

    private static func assertSuccess(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw AuthError.badResponse((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
    }

    private struct UserPayload: Decodable {
        let name: String
        let foods: [String]
    }
}

enum AuthError: Error, Sendable {
    case badResponse(Int)
}
```

A few things worth a closer look:

- **`final class` + `Sendable`.** Reference type because `URLSession` is a reference type and we want one instance shared across the napkin tree. `final` + immutable stored properties + `Sendable`-conforming property types = the compiler infers `Sendable` automatically.
- **Decoder is a `let` instance variable**, not a fresh one per call. JSONDecoder is reasonably expensive to construct and threadsafe to read from.
- **`URLSession.data(for:)` is the modern async API.** It returns `(Data, URLResponse)` and propagates cancellation. If the calling task is cancelled (e.g. user navigates away mid-request), the request is cancelled too.
- **`AuthError` is `Sendable`** so it can cross actor boundaries when thrown.

## Step 3: Wire it in at the dependency root

The only line that changes is in `SceneDelegate.swift`'s `AppComponent`:

```swift
final class AppComponent: Component<EmptyDependency>, LaunchNapkinDependency, @unchecked Sendable {
    let authService: AuthService

    init() {
        let api = URL(string: "https://api.smokehouse.example/v1")!
        self.authService = URLSessionAuthService(baseURL: api)
        super.init(dependency: EmptyComponent())
    }
}
```

That's it. No interactor, router, builder, or view file changes. The mock is gone; the network service takes its place. Every napkin in the tree still reads `dependency.authService` and gets *the same protocol*.

> Note: A production app would inject the base URL from configuration (build setting, `Info.plist`, environment variable, feature flag service). Hardcoding it in `AppComponent.init` is fine for the example.

## Step 4: Handling cancellation

Long network requests should cancel when their work is no longer needed. The napkin pattern already gives you this for free:

```swift
final actor LaunchNapkinInteractor: ... {
    func loggedOutDidTapLogin() async {
        do {
            let user = try await authService.login()
            await router?.attachLoggedIn(user: user)
        } catch is CancellationError {
            // The user navigated away before the request completed —
            // nothing to do. The actor has already been deactivated.
        } catch {
            // Real failure: log, surface, or stay on logged-out.
        }
    }
}
```

A `CancellationError` from `URLSession.data(for:)` means the parent task was cancelled — usually because the napkin is being torn down. Bail silently. Any other error is a real failure (network down, bad credentials, server 500).

> Important: `URLSessionAuthService` doesn't need its own cancellation plumbing. Swift's `async`/`await` propagates cancellation through the task hierarchy automatically. If the LaunchNapkin's interactor task is cancelled, the in-flight `URLSession` request is cancelled too.

## Step 5: Testing the swap

The interactor tests written against the *mock* in <doc:TestingANapkin> don't need to change when you swap implementations. They test that the interactor calls the protocol correctly — not what the protocol does behind the scenes.

For the `URLSessionAuthService` itself, a separate test exercises just the networking concern, often against a mocked `URLSession` or `URLProtocol` subclass. That's a "service test" — out of scope here, but the typical shape:

```swift
final class URLSessionAuthServiceTests: XCTestCase {
    func testLogin_returnsDecodedUser() async throws {
        // Spin up a URLProtocol that intercepts requests and returns canned JSON.
        // Configure a URLSession with that protocol class in its configuration.
        // Assert that calling login() returns a User with the expected fields.
    }
}
```

The point: separating the protocol (LaunchNapkin's concern) from the impl (network concern) means you write *two small tests* instead of one tangled integration test.

## What didn't change

If you've come from a "view model talks to a singleton" style codebase, the most interesting thing about this swap is what *didn't* need to change:

- **The LaunchInteractor**. Same method body, same `try await authService.login()`.
- **The LaunchRouter**. Same `attachLoggedIn(user:)`.
- **Every child napkin**. The LoggedOut and LoggedIn napkins never knew the service existed.
- **The tests**. Mock-based interactor tests assert on the contract, not the implementation.

That's the dependency-injection-via-protocol pattern doing exactly what it's supposed to do. Swap the leaf, leave the tree alone.

## Topics

### Related

@Links(visualStyle: detailedGrid) {
    - <doc:TutorialBuildingALoginFlow>
    - <doc:TestingANapkin>
    - <doc:CrossIsolationPatterns>
}
