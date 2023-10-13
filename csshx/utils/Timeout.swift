//
//  Timeout.swift
//  csshx
//
//  Created by Jean-Daniel Dupas on 07/10/2023.
//

struct TimedOutError: Error, Equatable {}

///
/// Execute an operation in the current task subject to a timeout.
///
/// - Parameters:
///   - interval: The duration in seconds `operation` is allowed to run before timing out.
///   - operation: The async operation to perform.
/// - Returns: Returns the result of `operation` if it completed in time.
/// - Throws: Throws ``TimedOutError`` if the timeout expires before `operation` completes.
///   If `operation` throws an error before the timeout expires, that error is propagated to the caller
///
public func withTimeout<R>(
  _ interval: Duration,
  operation: @escaping @Sendable () async throws -> R
) async throws -> R {
  return try await withThrowingTaskGroup(of: R.self) { group in
    defer {
      group.cancelAll()
    }

    // Start actual work.
    group.addTask {
      let result = try await operation()
      try Task.checkCancellation()
      return result
    }
    // Start timeout child task.
    group.addTask {
      try await Task.sleep(for: interval)
      try Task.checkCancellation()
      // We’ve reached the timeout.
      throw TimedOutError()
    }
    // First finished child task wins, cancel the other task.
    let result = try await group.next()!
    return result
  }
}
