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

import Combine
import UIKit

/// The status of leak detection operations.
///
/// Use this enum to track whether leak detection is currently monitoring
/// objects or has completed all pending checks.
///
/// ## Usage
///
/// Subscribe to ``LeakDetector/status`` to monitor detection progress:
///
/// ```swift
/// LeakDetector.instance.status
///     .sink { status in
///         switch status {
///         case .InProgress:
///             print("Leak detection is running...")
///         case .DidComplete:
///             print("All leak checks completed")
///         }
///     }
///     .store(in: &cancellables)
/// ```
///
/// ## Topics
///
/// ### Status Values
///
/// - ``InProgress``
/// - ``DidComplete``
public enum LeakDetectionStatus {

    /// Leak detection is currently in progress.
    ///
    /// One or more objects are being monitored for deallocation.
    case InProgress

    /// Leak detection has completed.
    ///
    /// All pending leak detection expectations have been resolved.
    case DidComplete
}

/// Default time intervals for leak detection expectations.
///
/// These constants define the standard time windows within which objects
/// are expected to be deallocated or views are expected to disappear.
///
/// ## Overview
///
/// When a napkin is detached, its components should deallocate within
/// a reasonable timeframe. These defaults represent typical expectations:
///
/// - Objects should deallocate within 1 second
/// - View controllers should disappear within 5 seconds
///
/// ## Customizing Timeouts
///
/// You can provide custom timeouts when setting expectations:
///
/// ```swift
/// // Use a longer timeout for complex teardown
/// LeakDetector.instance.expectDeallocate(
///     object: complexObject,
///     inTime: 3.0
/// )
/// ```
///
/// ## Topics
///
/// ### Time Constants
///
/// - ``deallocation``
/// - ``viewDisappear``
public struct LeakDefaultExpectationTime {

    /// The default time for object deallocation (1 second).
    ///
    /// Objects like interactors, routers, and components should typically
    /// deallocate within this timeframe after being released.
    public static let deallocation = 1.0

    /// The default time for view controller disappearance (5 seconds).
    ///
    /// View controllers may take longer to disappear due to animations
    /// and UI lifecycle events.
    public static let viewDisappear = 5.0
}

/// A handle for managing a scheduled leak detection expectation.
///
/// Use this handle to cancel a leak detection check before it completes.
/// This is useful when you know an object will be retained longer than
/// expected for legitimate reasons.
///
/// ## Usage
///
/// ```swift
/// let handle = LeakDetector.instance.expectDeallocate(object: myObject)
///
/// // Later, if the object is intentionally retained
/// handle.cancel()
/// ```
///
/// ## Topics
///
/// ### Cancellation
///
/// - ``cancel()``
public protocol LeakDetectionHandle {

    /// Cancels the scheduled leak detection.
    ///
    /// Call this method when you determine that an object should not
    /// be checked for deallocation. After cancellation, no assertion
    /// will be triggered for this expectation.
    func cancel()
}

/// An expectation-based memory leak detector for napkin architectures.
///
/// `LeakDetector` helps identify memory leaks by setting expectations that
/// objects will be deallocated within a specified timeframe. If an object
/// fails to deallocate, a runtime assertion is triggered during development.
///
/// ## Overview
///
/// Memory leaks in napkin architectures typically occur when:
/// - Retain cycles exist between interactors and listeners
/// - Child routers aren't properly detached
/// - Closures strongly capture napkin components
/// - View controllers are retained after dismissal
///
/// The leak detector catches these issues during development by verifying
/// that objects deallocate when expected.
///
/// ## Usage
///
/// The leak detector is automatically used by napkin's `Router` class.
/// You can also use it manually for custom objects:
///
/// ```swift
/// // In Router's detachChild implementation
/// override func detachChild(_ child: Routing) {
///     super.detachChild(child)
///
///     // Expect the child's interactor to deallocate
///     LeakDetector.instance.expectDeallocate(
///         object: child.interactable
///     )
/// }
/// ```
///
/// ## Monitoring Status
///
/// Subscribe to the ``status`` publisher to know when all leak checks complete:
///
/// ```swift
/// LeakDetector.instance.status
///     .filter { $0 == .DidComplete }
///     .sink { _ in
///         print("All leak checks passed")
///     }
///     .store(in: &cancellables)
/// ```
///
/// ## Disabling in Production
///
/// Leak detection is designed for development and is disabled in release builds.
/// You can also disable it via environment variable:
///
/// ```bash
/// DISABLE_LEAK_DETECTION=YES
/// ```
///
/// ## Topics
///
/// ### Accessing the Detector
///
/// - ``instance``
/// - ``status``
///
/// ### Setting Expectations
///
/// - ``expectDeallocate(object:inTime:)``
/// - ``expectViewControllerDisappear(viewController:inTime:)``
///
/// - SeeAlso: ``LeakDetectionStatus``
/// - SeeAlso: ``LeakDetectionHandle``
/// - SeeAlso: ``LeakDefaultExpectationTime``
public class LeakDetector {

    /// The shared singleton instance of the leak detector.
    ///
    /// Use this instance to set leak detection expectations throughout
    /// your application.
    public static let instance = LeakDetector()

    /// A publisher emitting the current leak detection status.
    ///
    /// The status transitions between ``LeakDetectionStatus/InProgress``
    /// and ``LeakDetectionStatus/DidComplete`` as expectations are registered,
    /// cancelled, or resolved.
    ///
    /// Use this to coordinate testing or cleanup activities:
    ///
    /// ```swift
    /// // Wait for all leak checks to complete before proceeding
    /// LeakDetector.instance.status
    ///     .first { $0 == .DidComplete }
    ///     .sink { _ in
    ///         // Safe to continue
    ///     }
    ///     .store(in: &cancellables)
    /// ```
    public var status: AnyPublisher<LeakDetectionStatus, Never> {
        return expectationCount
            .map { expectationCount in
                expectationCount > 0 ? LeakDetectionStatus.InProgress : LeakDetectionStatus.DidComplete
            }
            .eraseToAnyPublisher()
    }

    /// Sets up an expectation that an object will be deallocated within a timeframe.
    ///
    /// Call this method when you expect an object to be deallocated soon,
    /// such as after detaching a child router. If the object is not
    /// deallocated within the specified time, an assertion failure occurs.
    ///
    /// ```swift
    /// // Expect interactor to deallocate after router detachment
    /// LeakDetector.instance.expectDeallocate(
    ///     object: childRouter.interactable,
    ///     inTime: 2.0
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - object: The object to track for deallocation.
    ///   - time: The time window within which deallocation should occur.
    ///           Defaults to ``LeakDefaultExpectationTime/deallocation``.
    /// - Returns: A handle that can be used to cancel the expectation.
    @discardableResult
    public func expectDeallocate(object: AnyObject, inTime time: TimeInterval = LeakDefaultExpectationTime.deallocation) -> LeakDetectionHandle {
        expectationCount.send(expectationCount.value + 1)

        let objectDescription = String(describing: object)
        let objectId = String(ObjectIdentifier(object).hashValue) as NSString
        trackingObjects.setObject(object, forKey: objectId)

        let handle = LeakDetectionHandleImpl {
            self.expectationCount.send(self.expectationCount.value - 1)
        }

        Executor.execute(withDelay: time) {
            // Retain the handle so we can check for the cancelled status. Also cannot use the cancellable
            // concurrency API since the returned handle must be retained to ensure closure is executed.
            if !handle.cancelled {
                let didDeallocate = (self.trackingObjects.object(forKey: objectId) == nil)
                let message = "<\(objectDescription): \(objectId)> has leaked. Objects are expected to be deallocated at this time: \(self.trackingObjects)"

                if self.disableLeakDetector {
                    if !didDeallocate {
                        print("Leak detection is disabled. This should only be used for debugging purposes.")
                        print(message)
                    }
                } else {
                    assert(didDeallocate, message)
                }
            }

            self.expectationCount.send(self.expectationCount.value - 1)
        }

        return handle
    }

    /// Sets up an expectation that a view controller will disappear within a timeframe.
    ///
    /// Call this method when you expect a view controller to be removed
    /// from the view hierarchy, such as after dismissing or popping it.
    /// If the view controller remains visible after the specified time,
    /// an assertion failure occurs.
    ///
    /// This catches common issues like:
    /// - View controllers not being dismissed after router detachment
    /// - View controllers being incorrectly reused without proper cleanup
    /// - Missing dismissal calls in custom navigation flows
    ///
    /// ```swift
    /// // Expect view controller to disappear after dismissal
    /// LeakDetector.instance.expectViewControllerDisappear(
    ///     viewController: childViewController,
    ///     inTime: 3.0
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - viewController: The view controller expected to disappear.
    ///   - time: The time window within which disappearance should occur.
    ///           Defaults to ``LeakDefaultExpectationTime/viewDisappear``.
    /// - Returns: A handle that can be used to cancel the expectation.
    @discardableResult
    public func expectViewControllerDisappear(viewController: UIViewController, inTime time: TimeInterval = LeakDefaultExpectationTime.viewDisappear) -> LeakDetectionHandle {
        expectationCount.send(expectationCount.value + 1)

        let handle = LeakDetectionHandleImpl {
            self.expectationCount.send(self.expectationCount.value - 1)
        }

        Executor.execute(withDelay: time) { [weak viewController] in
            // Retain the handle so we can check for the cancelled status. Also cannot use the cancellable
            // concurrency API since the returned handle must be retained to ensure closure is executed.
            if let viewController = viewController, !handle.cancelled {
                let viewDidDisappear = (!viewController.isViewLoaded || viewController.view.window == nil)
                let message = "\(viewController) appearance has leaked. Either its parent router who does not own a view controller was detached, but failed to dismiss the leaked view controller; or the view controller is reused and re-added to window, yet the router is not re-attached but re-created. Objects are expected to be deallocated at this time: \(self.trackingObjects)"

                if self.disableLeakDetector {
                    if !viewDidDisappear {
                        print("Leak detection is disabled. This should only be used for debugging purposes.")
                        print(message)
                    }
                } else {
                    assert(viewDidDisappear, message)
                }
            }

            self.expectationCount.send(self.expectationCount.value - 1)
        }

        return handle
    }

    // MARK: - Internal Interface

    // Test override for leak detectors.
    static var disableLeakDetectorOverride: Bool = false

    #if DEBUG
        /// Reset the state of Leak Detector, internal for UI test only.
        func reset() {
            trackingObjects.removeAllObjects()
            expectationCount.send(0)
        }
    #endif

    // MARK: - Private Interface

    private let trackingObjects = NSMapTable<AnyObject, AnyObject>.strongToWeakObjects()
    private let expectationCount = CurrentValueSubject<Int, Never>(0)

    lazy var disableLeakDetector: Bool = {
        if let environmentValue = ProcessInfo().environment["DISABLE_LEAK_DETECTION"] {
            let lowercase = environmentValue.lowercased()
            return lowercase == "yes" || lowercase == "true"
        }
        return LeakDetector.disableLeakDetectorOverride
    }()

    private init() {}
}

fileprivate class LeakDetectionHandleImpl: LeakDetectionHandle {

    var cancelled: Bool {
        return cancelledRelay.value
    }

    let cancelledRelay = CurrentValueSubject<Bool, Never>(false)
    let cancelClosure: (() -> ())?

    init(cancelClosure: (() -> ())? = nil) {
        self.cancelClosure = cancelClosure
    }

    func cancel() {
        cancelledRelay.send(true)
        cancelClosure?()
    }
}
