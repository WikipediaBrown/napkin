# README: Streaming State Down the Tree (Combine → Swift Concurrency)

- **Date:** 2026-07-02
- **Status:** Draft — awaiting user review. Four decisions were defaulted while the user was away; each is flagged **[DEFAULTED]** below and can be overridden at review.
- **Branch:** `docs/readme-streaming-examples`

## Problem

The single biggest blocker reported by users migrating from Combine-era napkin (0.x) to the Swift Concurrency package (2.x) is **streaming events down the tree of napkins**. Research across the repo, git history, and a reference production app pinpointed why:

1. **Every existing doc shows only the consumer side.** README:255-259, `MigratingFromV0.md:123-131`, `Lifecycle.md:40-50`, and `HeadlessNapkins.md:82-92` all consume `userService.userStream` / `eventBus.events` — but no document, snippet, or example anywhere in the repo shows how to **build** the stream-vending service. In 0.x, users wrote that half themselves with Combine subjects on a service shared via `Component.shared {}` (0.0.30 README shows exactly this). They know the producer pattern in Combine; nobody has shown them its concurrency equivalent.
2. **The multicast trap is real and undocumented.** `AsyncStream` is single-consumer (concurrent `next()` is a documented programmer error per SE-0314), while Combine publishers multicast. "Stream state down the tree" usually means multiple children subscribing; a naive `AsyncStream` stored property breaks exactly there. No doc mentions this.
3. **The reference app confirms the real-world "before" shape.** Scrillionaire-iOS (napkin 0.x in production) has `AuthenticationManager` owning `PassthroughSubject<User?, Error>` fed by a Firebase callback, and `RootInteractor.didBecomeActive` subscribing with `.catch { presentError; reset().userSubject }.retry(.max).assertNoFailure().sink(receiveValue: handleUser).store(in: &cancellables)`. The `catch/reset/retry` ceremony exists only because Combine completions are terminal — the concurrency version deletes it rather than translating it.

The framework already contains the canonical producer-side answer: `InteractorLifecycle.isActiveStream` (Sources/napkin/InteractorLifecycle.swift:122) vends a fresh per-subscriber stream that yields the current value then every transition — `CurrentValueSubject` semantics, in-repo.

## Goals

- README examples showing how to replicate Combine streaming functionality with Swift Concurrency, centered on the producer side (the documented gap).
- Explicitly defuse the `AsyncStream` single-consumer trap.
- Show migrating users their own code: a recognizable Combine "before" mapped to a better "after."
- Examples that cannot rot: compiled by CI.

## Non-goals (follow-ups, not in this change)

- Extending RibHouse to exercise streaming (it currently has zero streaming code; auth is one-shot request/response).
- A new DocC article (this content can be lifted into one later).
- Adding producer-side rows to `MigratingFromV0.md`'s diff table.
- Any framework API additions — this is documentation only. The README teaches a user-space pattern; napkin deliberately ships no subject/bus primitive (per the 2026-05-04 rearchitecture spec: "`@Observable` covers state; `AsyncStream` / `async` functions cover events").

## Design

### New top-level README section: "Streaming State Down the Tree"

Placement: between **Routing & Navigation** and **Launching the App**. ToC entry added. The line "Data flows down the tree. Events flow up via listener protocols." (README:90) gains a link to the section. The existing `Observations({ userService.currentUser })` snippet in the Interactor section (README:255-259) gains a pointer to this section, which finally defines the service that snippet implies.

The section has five parts:

#### 1. Framing intro (~4 sentences)

Build-time injection covers initial values; for *ongoing* values, Combine users put a subject on a service shared via the parent's `Component` and threaded down through `Dependency` protocols. That architecture is unchanged in 2.x — only the stream primitive changes. State (has a current value) and events (fire-and-forget) are different shapes with different tools.

#### 2. Combine → napkin 2.x mapping table

| Combine | napkin 2.x | Note |
|---|---|---|
| `CurrentValueSubject` | `actor` service with replay-latest fan-out streams | Replays current value; one fresh stream per subscriber |
| `@Published` / `ObservableObject` | `@Observable` service + `Observations {}` | Multi-consumer; primed with current value (SE-0475) |
| `PassthroughSubject` | Same fan-out actor, minus the initial `yield` | No replay |
| `.sink {}.store(in: &cancellables)` | `task { for await … }` | Auto-cancelled on deactivate — 0.x never had this |
| `.catch` / `.retry` / subject `reset()` | `async throws` at the call site | Streams carry state, not failure; they never terminate on error |
| `.receive(on: DispatchQueue.main)` | `await presenter.…` | Isolation crossing is explicit |
| `assign(to:on:)` | Set the `@Observable` presenter property in the loop body | |
| `combineLatest` / `merge` / `debounce` / `removeDuplicates` | [swift-async-algorithms](https://github.com/apple/swift-async-algorithms) | Official Apple package, not stdlib |

#### 3. Worked example — the spine: auth state with a root auth gate

Domain chosen deliberately: matches the reference production app (`AuthenticationManager` → `RootInteractor`), RibHouse (`AuthService`, `User`, LaunchNapkin swapping LoggedIn/LoggedOut), and the classic RIBs demo.

**Before (Combine, collapsed in a `<details>` block, ~25 lines):** manager owning `PassthroughSubject<User?, Error>` fed by a callback API; root interactor subscribing with the `catch/reset/retry/assertNoFailure/sink/store` chain; `handleUser` routing `.some` → home, `.none` → login.

**After — producer (the never-before-documented half):**

```swift
/// Replaces CurrentValueSubject: replays the current value to each new
/// subscriber, fans out to any number of subscribers, never terminates
/// on error. Same shape as the framework's own
/// `InteractorLifecycle.isActiveStream`.
actor AuthenticationService {

    private(set) var currentUser: User?
    private var subscribers: [UUID: AsyncStream<User?>.Continuation] = [:]

    /// A fresh stream per subscriber: the current value immediately,
    /// then every change. (`AsyncStream` is single-consumer — vending
    /// a new stream per call is what makes fan-out safe.)
    func userStream() -> AsyncStream<User?> {
        let (stream, continuation) = AsyncStream.makeStream(of: User?.self)
        let id = UUID()
        subscribers[id] = continuation
        continuation.yield(currentUser)            // ← replay: delete this line for PassthroughSubject semantics
        continuation.onTermination = { [weak self] _ in
            Task { await self?.removeSubscriber(id) }
        }
        return stream
    }

    /// Errors surface here, at the call site that triggered the work —
    /// not on the stream. This is why the Combine version's
    /// catch/reset/retry chain has no translation: it has no job left.
    func signIn() async throws -> User { /* … set state, notify … */ }
    func signOut() async throws { /* … */ }

    private func setUser(_ user: User?) {
        currentUser = user
        for continuation in subscribers.values { continuation.yield(user) }
    }

    private func removeSubscriber(_ id: UUID) {
        subscribers[id]?.finish()
        subscribers.removeValue(forKey: id)
    }
}
```

Notes the example must carry:
- The actor **is** the lock — unlike the framework-internal `InteractorLifecycle` (which needs a `Mutex` because `isActiveStream` is `nonisolated`), user code needs no `@unchecked Sendable` and no `Synchronization` import.
- Callback-API adaptation (the Firebase-listener shape from the reference app) shown as a short sketch: external callback → `Task { await self.setUser(user) }`. Exact spelling settled at compile time during implementation.
- The `actor` satisfies `Dependency`'s `Sendable` requirement by construction, and business state stays **off the main actor** — the architecture's core promise (AGENTS.md: don't make things `@MainActor` for convenience).

**After — DI wiring (condensed, ~8 lines):** `shared { AuthenticationService() }` in the parent Component, forwarded through child `Dependency` protocols — pattern already documented, shown tersely.

**After — consumers (two, to prove multicast):**

```swift
// Root napkin: the auth gate.
func didBecomeActive() async {
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
```

A second, deeper child (e.g. a profile napkin) subscribes to the *same service* via its own `userStream()` call — one line of prose + a 5-line snippet making the fan-out explicit. Replay means a child attached after login immediately learns the state — an upgrade over the `PassthroughSubject` original, which depended on the upstream callback re-firing.

**Callout (warning-style):** the deleted `catch/reset/retry` chain, shown struck-through or quoted, with the two-sentence explanation: Combine completions are terminal, so a long-lived stream needed subject-swapping ceremony to survive errors; concurrency streams carry only state and errors return at the call site.

#### 4. Events variant (~10 lines + callout)

`PassthroughSubject` replacement: same actor pattern minus the initial `yield` (the one-line diff is the teaching beat). Warning callout names the single-consumer trap explicitly: never share one `AsyncStream` instance among subscribers; vend fresh streams.

#### 5. `@Observable` variant (~15 lines)

When the state is main-actor-friendly (view-adjacent session state), a `@MainActor @Observable final class UserService` consumed via `task { for await user in Observations({ … }) }` — defining the service that README:255-259 already implies. Notes: `Observations` is multi-consumer and primes each iterator with the current value (SE-0475, iOS 26 — already napkin's floor); closure isolation must match the service's isolation (exact spelling compile-verified during implementation).

Section closes with links: [migratingfromv0](https://getnapkin.to/documentation/napkin/migratingfromv0), [lifecycle](https://getnapkin.to/documentation/napkin/lifecycle), [crossisolationpatterns](https://getnapkin.to/documentation/napkin/crossisolationpatterns).

### Compiled snippets

All example code lands in `Snippets/Streaming/` (e.g. `AuthStateStreaming.swift`, `EventStreaming.swift`, `ObservableStateStreaming.swift` — final names follow existing `Snippets/` conventions), compiled by `swift build` so CI fails if the framework drifts from the README. The README code blocks are copies kept in sync by hand — GitHub can't embed snippets — with a comment in each snippet file naming the README section it mirrors. (Existing `Snippets/` files are referenced by DocC articles; these can be adopted by a future DocC article the same way.)

## Defaulted decisions [user may override at review]

1. **[DEFAULTED] Design approved as revised** — auth-state spine example incorporating the Scrillionaire reference the user supplied.
2. **[DEFAULTED] Before/after style: short collapsed `<details>` Combine block** — migrating users recognize their code; new users aren't taxed. Alternatives: fully visible side-by-side, or concurrency-only with a MigratingFromV0 link.
3. **[DEFAULTED] Compiled snippets: yes** — `Snippets/Streaming/` guarded by `swift build` in CI. Alternative: README-only (still compile-verified once, unguarded after).
4. **[DEFAULTED] Lead recipe: actor broadcaster** — keeps business state off the main actor per the architecture; `@Observable`+`Observations` is the secondary variant. Alternative: lead with `@Observable` (simpler code, but pins shared state to the main actor).

## Verification

- Every snippet compiles via SwiftPM (`swift build`) against the framework before entering the README; `swift test` stays green.
- The `Observations` closure-isolation spelling and the callback-adaptation `self` capture in `init` are the two known compile-risk points; both get settled in the snippet target first, README text second.
- README rendered locally (or on the PR) to check the `<details>` block, table, and anchors.

## Error handling in the examples themselves

- `signIn()` failures: shown propagating to the caller (`try await` at the point of user intent), presenter shows the error — no global error channel.
- Stream teardown: `onTermination` removes the subscriber; consumer tasks are lifecycle-bound via `task {}` so detach cancels them, which fires `onTermination`, which cleans the actor's table. This loop is stated in one sentence in the README so readers see there is no leak path.
