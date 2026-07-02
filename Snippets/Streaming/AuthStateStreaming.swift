// snippet.hide
//
// Compiled mirror of README.md § "Streaming State Down the Tree" —
// state (CurrentValueSubject replacement) and the service-to-screen
// vertical. Keep the README code blocks in sync with the
// `snippet.show` regions of this file.
//
import napkin
import Foundation
import SwiftUI

#if canImport(UIKit)
import UIKit
typealias PlatformViewController = UIViewController
#elseif canImport(AppKit)
import AppKit
typealias PlatformViewController = NSViewController
#endif

struct User: Sendable, Equatable {
    let name: String
}

struct AuthClient {
    func addStateDidChangeListener(_ handler: @escaping @Sendable (User?) -> Void) {}
}
// snippet.show

// MARK: - Producer (the service the parent's Component shares)

/// Replaces `CurrentValueSubject`: replays the current value to each new
/// subscriber, fans out to any number of subscribers, and never
/// terminates on error. Same shape as the framework's own
/// `isActiveStream`. The actor is the lock — no `Mutex`, no
/// `@unchecked Sendable`.
actor AuthenticationService {

    private(set) var currentUser: User?
    private var subscribers: [UUID: AsyncStream<User?>.Continuation] = [:]

    /// A fresh stream per subscriber: the current value immediately,
    /// then every change. `AsyncStream` is single-consumer — vending a
    /// new stream per call is what makes fan-out safe.
    func userStream() -> AsyncStream<User?> {
        let (stream, continuation) = AsyncStream.makeStream(of: User?.self)
        let id = UUID()
        subscribers[id] = continuation
        continuation.yield(currentUser)
        continuation.onTermination = { [weak self] _ in
            Task { await self?.removeSubscriber(id) }
        }
        return stream
    }

    /// Errors surface here, at the call site that asked — not on the
    /// stream. This is why the Combine version's catch/reset/retry
    /// ceremony has no translation: it has no job left.
    func signIn(name: String) async throws -> User {
        let user = User(name: name)   // e.g. try await backend.signIn()
        setUser(user)
        return user
    }

    func signOut() async throws {
        setUser(nil)                  // e.g. try await backend.signOut()
    }

    /// Adapting a callback API — the 0.x manager wrapped an auth
    /// SDK's state-change listener; the 2.x service hops the callback
    /// onto the actor:
    func bind(to auth: AuthClient) {
        auth.addStateDidChangeListener { user in
            Task { await self.setUser(user) }
        }
    }

    private func setUser(_ user: User?) {
        currentUser = user
        for continuation in subscribers.values {
            continuation.yield(user)
        }
    }

    private func removeSubscriber(_ id: UUID) {
        subscribers[id]?.finish()
        subscribers.removeValue(forKey: id)
    }
}

// MARK: - Sharing it down the tree (unchanged from 0.x)

protocol RootDependency: Dependency {}

final class RootComponent: Component<RootDependency>, @unchecked Sendable {
    var authService: AuthenticationService {
        shared { AuthenticationService() }
    }
}

protocol ProfileDependency: Dependency {
    var authService: AuthenticationService { get }
}

extension RootComponent: ProfileDependency {}

// MARK: - Consumer 1: the root auth gate

@MainActor
protocol RootRouting: ViewableRouting, Sendable {
    func routeToHome(user: User) async
    func routeToLogin() async
}

final actor RootInteractor: Interactable {

    nonisolated let lifecycle = InteractorLifecycle()

    weak var router: RootRouting?

    private let authService: AuthenticationService

    init(authService: AuthenticationService) {
        self.authService = authService
    }

    func didBecomeActive() async {
        // One long-lived subscription drives routing. Bound to the
        // active scope: cancelled automatically on willResignActive.
        task {
            for await user in await self.authService.userStream() {
                if let user {
                    await self.router?.routeToHome(user: user)
                } else {
                    await self.router?.routeToLogin()
                }
            }
        }
    }
}

// MARK: - Consumer 2: a deeper napkin carries the value to the screen

protocol ProfilePresentable: Presentable, Sendable {
    func present(greeting: String) async
}

final actor ProfileInteractor: PresentableInteractable {

    nonisolated let lifecycle = InteractorLifecycle()
    nonisolated let presenter: ProfilePresentable

    private let authService: AuthenticationService

    init(presenter: ProfilePresentable, authService: AuthenticationService) {
        self.presenter = presenter
        self.authService = authService
    }

    func didBecomeActive() async {
        task {
            // A second, independent stream from the same service: the
            // root gate above and this napkin both see every change.
            for await user in await self.authService.userStream() {
                // What `.map` did mid-pipeline is now plain code.
                let greeting = user.map { "Welcome back, \($0.name)" } ?? "Signed out"
                // The `await` is the main-actor crossing — this is
                // where `.receive(on: DispatchQueue.main)` went.
                await self.presenter.present(greeting: greeting)
            }
        }
    }
}

// snippet.hide
@MainActor
protocol ProfileViewControllable: ViewControllable {}

@MainActor
final class ProfileViewController: PlatformViewController, ProfileViewControllable {}
// snippet.show

// MARK: - The presenter is the view model

@MainActor
@Observable
final class ProfilePresenter: Presenter<ProfileViewController>, ProfilePresentable {

    var greeting: String = ""

    func present(greeting: String) async {
        self.greeting = greeting
    }
}

struct ProfileView: View {
    // Weak: the presenter owns the view controller, which owns this view —
    // a strong reference here would be a retain cycle. The interactor keeps
    // the presenter alive for the napkin's whole attached lifetime.
    weak var presenter: ProfilePresenter?

    var body: some View {
        Text(presenter?.greeting ?? "")
    }
}
