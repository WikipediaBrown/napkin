// snippet.hide
//
// Compiled mirror of README.md § "Streaming State Down the Tree" —
// main-actor state via @Observable + Observations. Keep the README
// code block in sync with the `snippet.show` region of this file.
//
// NOTE: iterating `Observations` directly inside the nonisolated
// `task {}` closure crashes the Swift 6.2 frontend (verified
// 2026-07-02). The `task { @MainActor [weak self] in … }` binding below is the
// working form — do not "simplify" it.
//
import napkin
import Foundation
import Observation

struct User: Sendable, Equatable {
    let name: String
}
// snippet.show

/// When state is main-actor-friendly anyway — view-adjacent session
/// state, say — skip the hand-rolled fan-out. An `@Observable` class
/// plus `Observations` gives you `CurrentValueSubject` semantics for
/// free: each iterator starts with the current value, and any number
/// of consumers can observe independently.
@MainActor
@Observable
final class UserService {

    private(set) var currentUser: User?

    func set(user: User?) {
        currentUser = user
    }
}

final actor SettingsInteractor: Interactable {

    nonisolated let lifecycle = InteractorLifecycle()

    private let userService: UserService

    init(userService: UserService) {
        self.userService = userService
    }

    func didBecomeActive() async {
        // The observation loop runs on the actor that owns the state —
        // bind it to the main actor, and hop back to this actor to
        // handle each value. Still lifecycle-bound: cancelled on
        // willResignActive.
        let userService = self.userService
        task { @MainActor [weak self] in
            for await user in Observations({ userService.currentUser }) {
                await self?.handle(user)
            }
        }
    }

    private func handle(_ user: User?) { /* … */ }
}
