//___FILEHEADER___

import napkin

/// The root composition component for the napkin tree.
///
/// `LaunchComponent` terminates the dependency graph — it has no parent
/// (`Component<EmptyDependency>`) — and is where the app's root services
/// are constructed. It conforms to `___VARIABLE_productName___Dependency`
/// so the launch napkin, and transitively every child napkin, can read
/// those services through the dependency tree.
///
/// Instantiate it once at app launch and hand it to the builder:
///
///     let builder = ___VARIABLE_productName___Builder(dependency: LaunchComponent())
///     let router = await builder.build(withListener: appListener)
///
/// `nonisolated` because `Component` is dependency-injection plumbing that
/// runs off any actor. Without it, a module whose **Default Actor
/// Isolation** build setting is `MainActor` (the Xcode 26 default) fails
/// to compile this subclass against napkin's `nonisolated` base.
nonisolated final class LaunchComponent: Component<EmptyDependency>, ___VARIABLE_productName___Dependency, @unchecked Sendable {

    // TODO: Declare the root services this app provides to the napkin tree.
    // let networkingService: NetworkingServicing

    init() {
        // TODO: Initialize the root services declared above.
        // networkingService = NetworkingService()
        super.init(dependency: EmptyComponent())
    }
}
