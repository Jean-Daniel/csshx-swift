//
//  Signal.swift
//  csshx
//
//  Created by Jean-Daniel Dupas on 10/10/2023.
//

import Dispatch

func waitFor<Source: DispatchSourceProtocol>(source: Source, event: String) async {
  // Add Task Cancellation handler to cancel the source when the Task is cancelled.
  await withTaskCancellationHandler {
    // If task already cancelled, the cancel handler may have already been invoked
    guard !source.isCancelled else {
      // A DispatchSource must be resume at least once, even if cancelled
      source.activate()
      return
    }

    // Waiting Dispatch Source first callback.
    await withCheckedContinuation { contination in
      source.setEventHandler {
        // let the cancellation handler resume the continuation
        logger.debug("\(event) received")
        source.cancel()
      }

      source.setCancelHandler {
        contination.resume()
      }
      // Start the dispatch source.
      logger.debug("waiting for \(event)")
      source.activate()
    }
  } onCancel: {
    logger.debug("cancelling handler for \(event)")
    source.cancel()
  }}

func waitFor(signal: Int32) async {
  let source = DispatchSource.makeSignalSource(signal: signal)
  await waitFor(source: source, event: "signal \(signal)")
}

func waitFor(pid: pid_t) async -> Int {
  let source = DispatchSource.makeProcessSource(identifier: pid, eventMask: .exit)
  await waitFor(source: source, event: "process \(pid) exit")
  var s: Int32 = 0
  if waitpid(pid, &s, WNOHANG) > 0 {
    return Int(s)
  }
  return 0
}

extension DispatchSource {
  static func signals(_ signal: Int32) -> AsyncStream<UInt> {
    AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
      let source = DispatchSource.makeSignalSource(signal: signal)
      source.setEventHandler {
        continuation.yield(source.data)
      }
      continuation.onTermination = { cause in
        source.cancel()
      }
      source.activate()
    }
  }
}
