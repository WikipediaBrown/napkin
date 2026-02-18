//
//  Copyright (c) 2017. Uber Technologies
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import UIKit

/// A protocol for the root router of an application.
///
/// `LaunchRouting` extends ``ViewableRouting`` to add the ability to launch
/// the entire router tree from an application window.
///
/// - SeeAlso: ``LaunchRouter``
public protocol LaunchRouting: ViewableRouting {

    /// Launches the router tree from the specified window.
    ///
    /// This method sets up the root view controller and activates the entire
    /// napkin tree, starting the application's business logic.
    ///
    /// - Parameter window: The application's main window.
    func launch(from window: UIWindow)
}

/// The root router for a napkin-based application.
///
/// `LaunchRouter` serves as the entry point for the entire napkin tree. It is
/// responsible for launching the application by setting up the root view controller
/// and activating the root interactor.
///
/// ## Overview
///
/// Use `LaunchRouter` as the base class for your application's root router.
/// The launch router:
/// - Sets the root view controller on the application window
/// - Makes the window visible
/// - Activates the root interactor
/// - Loads the router tree
///
/// ## Usage
///
/// ### Creating the Root Router
///
/// ```swift
/// final class RootRouter: LaunchRouter<RootInteractor, RootViewController>,
///                         RootRouting {
///
///     private let homeBuilder: HomeBuildable
///     private var homeRouter: HomeRouting?
///
///     init(interactor: RootInteractor,
///          viewController: RootViewController,
///          homeBuilder: HomeBuildable) {
///         self.homeBuilder = homeBuilder
///         super.init(interactor: interactor, viewController: viewController)
///         interactor.router = self
///     }
///
///     override func didLoad() {
///         super.didLoad()
///         // Attach the initial child router
///         routeToHome()
///     }
///
///     func routeToHome() {
///         let router = homeBuilder.build(withListener: interactor)
///         homeRouter = router
///         attachChild(router)
///     }
/// }
/// ```
///
/// ### Launching from AppDelegate
///
/// ```swift
/// @main
/// class AppDelegate: UIResponder, UIApplicationDelegate {
///
///     var window: UIWindow?
///     private var launchRouter: LaunchRouting?
///
///     func application(_ application: UIApplication,
///                      didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
///
///         let window = UIWindow(frame: UIScreen.main.bounds)
///         self.window = window
///
///         let component = AppComponent()
///         let rootBuilder = RootBuilder(dependency: component)
///         let launchRouter = rootBuilder.build()
///         self.launchRouter = launchRouter
///
///         launchRouter.launch(from: window)
///
///         return true
///     }
/// }
/// ```
///
/// ### Launching from SceneDelegate
///
/// ```swift
/// class SceneDelegate: UIResponder, UIWindowSceneDelegate {
///
///     var window: UIWindow?
///     private var launchRouter: LaunchRouting?
///
///     func scene(_ scene: UIScene,
///                willConnectTo session: UISceneSession,
///                options connectionOptions: UIScene.ConnectionOptions) {
///
///         guard let windowScene = scene as? UIWindowScene else { return }
///
///         let window = UIWindow(windowScene: windowScene)
///         self.window = window
///
///         let component = AppComponent()
///         let rootBuilder = RootBuilder(dependency: component)
///         let launchRouter = rootBuilder.build()
///         self.launchRouter = launchRouter
///
///         launchRouter.launch(from: window)
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
open class LaunchRouter<InteractorType, ViewControllerType>: ViewableRouter<InteractorType, ViewControllerType>, LaunchRouting {

    /// Creates a launch router with the specified interactor and view controller.
    ///
    /// - Parameters:
    ///   - interactor: The root interactor for the application.
    ///   - viewController: The root view controller that will be set on the window.
    public override init(interactor: InteractorType, viewController: ViewControllerType) {
        super.init(interactor: interactor, viewController: viewController)
    }

    /// Launches the application's router tree.
    ///
    /// This method performs the following steps:
    /// 1. Sets the root view controller on the window
    /// 2. Makes the window key and visible
    /// 3. Activates the root interactor
    /// 4. Loads the router (triggering ``Router/didLoad()``)
    ///
    /// - Parameter window: The application window to launch from.
    ///
    /// - Important: This method should only be called once, typically in
    ///   `application(_:didFinishLaunchingWithOptions:)` or
    ///   `scene(_:willConnectTo:options:)`.
    public final func launch(from window: UIWindow) {
        window.rootViewController = viewControllable.uiviewController
        window.makeKeyAndVisible()

        interactable.activate()
        load()
    }
}
