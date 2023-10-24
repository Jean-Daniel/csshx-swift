//
//  Signal.swift
//  csshx
//
//  Created by Jean-Daniel Dupas on 10/10/2023.
//

import Dispatch

// source must be scheduled on DispatchQueue.main to avoid concurrency issues
private func waitFor<Source: DispatchSourceProtocol>(source: Source,
                                                     event: String,
                                                     timeout: DispatchTimeInterval,
                                                     handler: @escaping (Bool) -> Void) {
  // Add Task Cancellation handler to cancel the source when the Task is cancelled.
  let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.main)
  timer.schedule(deadline: DispatchTime.now() + timeout)

  timer.setEventHandler {
    // timeout -> call the handler and cancel the other source
    handler(true)

    source.cancel()
    timer.cancel()
  }

  source.setEventHandler {
    logger.debug("\(event) received")
    handler(false)
    source.cancel()
    timer.cancel()
  }

  // Start the dispatch source and the timer.
  source.activate()
  timer.activate()
}

func waitFor(signal: Int32, timeout: DispatchTimeInterval, handler: @escaping (Bool) -> Void) {
  let source = DispatchSource.makeSignalSource(signal: signal)
  waitFor(source: source, event: "signal \(signal)", timeout: timeout, handler: handler)
}

func waitFor(pid: pid_t, handler: @escaping (Int) -> Void) {
  let source = DispatchSource.makeProcessSource(identifier: pid, eventMask: .exit)
  waitFor(source: source, event: "process \(pid) exit", timeout: .never) { timeout in
    var s: Int32 = 0
    if waitpid(pid, &s, WNOHANG) > 0 {
      handler(Int(s))
    } else {
      handler(0)
    }
  }
}
