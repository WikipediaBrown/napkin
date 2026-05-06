//
//  Copyright (c) 2017. Uber Technologies
//  Licensed under the Apache License, Version 2.0
//

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// A protocol for the root router of an application.
///
/// `LaunchRouting` extends ``ViewableRouting`` (and transitively ``Routing``)
/// with a single entry-point method, ``launch(from:)``, that installs the
/// root view controller into a host window and brings the napkin tree to
/// life.
///
/// ## Overview
///
/// On Apple platforms there is exactly one `LaunchRouting` per scene/window.
/// It is constructed by the application's root builder and then passed a
/// `UIWindow` (iOS / tvOS / Mac Catalyst) or `NSWindow` (macOS) to attach
/// to. After ``launch(from:)`` returns, the root interactor is active and
/// the router is `loaded()`.
///
/// ## Topics
///
/// ### Launching
///
/// - ``launch(from:)``
///
/// - SeeAlso: ``ViewableRouting``
/// - SeeAlso: ``Routing``
/// - SeeAlso: ``LaunchRouter``
@MainActor
public protocol LaunchRouting: ViewableRouting {
#if canImport(UIKit)
    /// Installs the root view controller into the given UIKit window and
    /// activates the root interactor.
    ///
    /// - Parameter window: The `UIWindow` that should host the napkin's
    ///   root view controller. The router sets `window.rootViewController`
    ///   and calls `makeKeyAndVisible()` before activating the interactor.
    func launch(from window: UIWindow) async
#elseif canImport(AppKit)
    /// Installs the root view controller into the given AppKit window and
    /// activates the root interactor.
    ///
    /// - Parameter window: The `NSWindow` that should host the napkin's
    ///   root view controller. The router sets `window.contentViewController`
    ///   and calls `makeKeyAndOrderFront(nil)` before activating the
    ///   interactor.
    func launch(from window: NSWindow) async
#endif
}

/// The root router for a napkin-based application.
///
/// `LaunchRouter` is a `@MainActor`-isolated subclass of ``ViewableRouter``
/// that adds the platform-specific ``launch(from:)`` entry point. Use it for
/// the single root router of each scene.
///
/// ## Overview
///
/// `launch(from:)` performs four steps in order:
///
/// 1. Installs the router's view controller as the window's root /
///    content view controller.
/// 2. Makes the window key and visible (UIKit) or key and ordered-front
///    (AppKit).
/// 3. `await`s ``Interactable/activate()`` on the root interactor.
/// 4. `await`s ``Router/load()``, which in turn awaits the root router's
///    ``Router/didLoad()``.
///
/// Because `launch(from:)` is `async`, its callers (typically a scene
/// delegate or `App`-level scene-builder) must hop into a `Task`.
///
/// ## Usage
///
/// **iOS scene delegate:**
///
/// ```swift
/// final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
///
///     var window: UIWindow?
///     var launchRouter: LaunchRouting?
///
///     func scene(
///         _ scene: UIScene,
///         willConnectTo session: UISceneSession,
///         options connectionOptions: UIScene.ConnectionOptions
///     ) {
///         guard let windowScene = scene as? UIWindowScene else { return }
///         let window = UIWindow(windowScene: windowScene)
///         self.window = window
///
///         Task { @MainActor in
///             let builder = RootBuilder(dependency: AppComponent())
///             let router = await builder.build()
///             self.launchRouter = router
///             await router.launch(from: window)
///         }
///     }
/// }
/// ```
///
/// **macOS app delegate:**
///
/// ```swift
/// final class AppDelegate: NSObject, NSApplicationDelegate {
///
///     var window: NSWindow!
///     var launchRouter: LaunchRouting?
///
///     func applicationDidFinishLaunching(_ notification: Notification) {
///         window = NSWindow(...)
///         Task { @MainActor in
///             let router = await RootBuilder(dependency: AppComponent()).build()
///             self.launchRouter = router
///             await router.launch(from: window)
///         }
///     }
/// }
/// ```
///
/// ## Topics
///
/// ### Creating a LaunchRouter
///
/// - ``init(interactor:viewController:)``
///
/// ### Launching
///
/// - ``launch(from:)``
///
/// - SeeAlso: ``LaunchRouting``
/// - SeeAlso: ``ViewableRouter``
@MainActor
open class LaunchRouter<InteractorType, ViewControllerType>:
    ViewableRouter<InteractorType, ViewControllerType>, LaunchRouting {

    /// Creates the application's root router.
    ///
    /// - Parameters:
    ///   - interactor: The root interactor.
    ///   - viewController: The root view controller. Must conform to
    ///     ``ViewControllable``.
    public override init(interactor: InteractorType, viewController: ViewControllerType) {
        super.init(interactor: interactor, viewController: viewController)
    }

#if canImport(UIKit)
    /// Installs the root view controller into the given window, activates
    /// the root interactor, and loads the router.
    ///
    /// Equivalent to:
    ///
    /// ```swift
    /// window.rootViewController = viewControllable.uiviewController
    /// window.makeKeyAndVisible()
    /// await interactable.activate()
    /// await load()
    /// ```
    ///
    /// - Parameter window: The `UIWindow` that should host the napkin's
    ///   root view controller.
    public final func launch(from window: UIWindow) async {
        window.rootViewController = viewControllable.uiviewController
        window.makeKeyAndVisible()
        await interactable.activate()
        await load()
    }
#elseif canImport(AppKit)
    /// Installs the root view controller into the given window, activates
    /// the root interactor, and loads the router.
    ///
    /// Equivalent to:
    ///
    /// ```swift
    /// window.contentViewController = viewControllable.nsviewController
    /// window.makeKeyAndOrderFront(nil)
    /// await interactable.activate()
    /// await load()
    /// ```
    ///
    /// - Parameter window: The `NSWindow` that should host the napkin's
    ///   root view controller.
    public final func launch(from window: NSWindow) async {
        window.contentViewController = viewControllable.nsviewController
        window.makeKeyAndOrderFront(nil)
        await interactable.activate()
        await load()
    }
#endif
}
