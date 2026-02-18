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

import Dispatch
import Foundation
import Combine

/// A utility for executing delayed logic with debugger-aware timing.
///
/// `Executor` provides a mechanism for scheduling delayed execution that
/// accounts for time spent paused in the debugger. This is essential for
/// leak detection, where breakpoint pauses shouldn't count toward
/// deallocation timeouts.
///
/// ## Overview
///
/// Standard delay mechanisms like `DispatchQueue.asyncAfter` count real
/// wall-clock time, including time spent paused at breakpoints. This causes
/// false positives in leak detection during debugging sessions.
///
/// `Executor` solves this by measuring actual application run time rather
/// than wall-clock time, excluding long pauses that exceed the expected
/// frame duration.
///
/// ## Usage
///
/// ```swift
/// // Execute after 2 seconds of actual app runtime
/// Executor.execute(withDelay: 2.0) {
///     print("This runs after 2 seconds of runtime")
/// }
///
/// // Custom frame duration for performance-sensitive code
/// Executor.execute(withDelay: 1.0, maxFrameDuration: 16) {
///     // More sensitive to dropped frames
/// }
/// ```
///
/// ## How It Works
///
/// The executor uses a timer that fires every `maxFrameDuration / 3`
/// milliseconds. Each tick, it measures elapsed time and caps it at
/// `maxFrameDuration`. This means if you pause in the debugger for
/// 10 seconds, only ~33ms is counted toward the delay.
///
/// ## Topics
///
/// ### Delayed Execution
///
/// - ``execute(withDelay:maxFrameDuration:logic:)``
///
/// - SeeAlso: ``LeakDetector``
public class Executor {

    /// Executes logic after a delay, excluding debugger pause time.
    ///
    /// This method schedules the given closure to execute after the
    /// specified delay of actual application runtime. Time spent paused
    /// in the debugger is not counted toward the delay.
    ///
    /// ```swift
    /// Executor.execute(withDelay: 1.0) {
    ///     // Verify object deallocation
    ///     assert(weakRef == nil, "Object should have deallocated")
    /// }
    /// ```
    ///
    /// - Note: The closure may execute later than the specified delay if
    ///   frames are dropped or the app is backgrounded. The delay represents
    ///   a minimum time, not an exact time.
    ///
    /// - Parameters:
    ///   - delay: The minimum delay before execution, measured in seconds
    ///            of actual application runtime.
    ///   - maxFrameDuration: The maximum time in milliseconds that a single
    ///                       frame should take. Time beyond this per frame
    ///                       is ignored (debugger pauses, etc.). Defaults to 33ms.
    ///   - logic: The closure to execute after the delay.
    public static func execute(withDelay delay: TimeInterval, maxFrameDuration: Int = 33, logic: @escaping () -> ()) {
        let period = TimeInterval(maxFrameDuration / 3)
        var lastRunLoopTime = Date().timeIntervalSinceReferenceDate
        var properFrameTime = 0.0
        
        _ = Timer
            .publish(every: period, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                let currentTime = Date().timeIntervalSinceReferenceDate
                let trueElapsedTime = currentTime - lastRunLoopTime
                lastRunLoopTime = currentTime
                
                // If we did drop frame, we under-count the frame duration, which is fine. It
                // just means the logic is performed slightly later.
                let boundedElapsedTime = min(trueElapsedTime, Double(maxFrameDuration) / 1000)
                properFrameTime += boundedElapsedTime
                if properFrameTime > delay {
                    logic()
                }
            }

    }
}
