//
//  Socket.swift
//  csshx
//
//  Created by Jean-Daniel Dupas on 12/10/2023.
//

import Foundation
import Network


class IOListener {

  private let path: String
  private let socket: Int32

  private var started = false

  fileprivate init(socket: Int32, path: String) {
    self.socket = socket
    self.path = path
  }

  private func _close() {
    Darwin.close(socket)
    unlink(path)
  }

  // Source cancel handler
  func close() {
    // If started, the async stream take reponsability for cleanup
    if (!started) {
      _close()
    }
  }

  func connections() -> AsyncThrowingStream<IOConnection, Error> {
    return AsyncThrowingStream(bufferingPolicy: .unbounded) { [socket] continuation in
      guard !started else {
        continuation.finish(throwing: POSIXError(.EBUSY))
        return
      }
      started = true
      
      let source = DispatchSource.makeReadSource(fileDescriptor: socket, queue: DispatchQueue.main)
      source.setEventHandler {
        print("ready to accept")
        var client_addr = sockaddr()
        var client_addrlen = UInt32(MemoryLayout.size(ofValue: client_addr))
        let client_fd = Darwin.accept(socket, &client_addr, &client_addrlen)
        print("accept() = \(client_fd)")
        if (client_fd < 0) {
          continuation.finish(throwing: POSIXError.errno)
        } else {
          do {
            try Bridge.setNonBlocking(client_fd)
            continuation.yield(IOConnection(socket: client_fd))
          } catch {
            Darwin.close(client_fd)
            print("client connection setup failed with error: \(error)")
          }
        }
      }
      source.setCancelHandler {
        self._close()
      }

      continuation.onTermination = { cause in
        source.cancel()
      }
      print("activate dispatch source")
      source.activate()
    }
  }
}


class IOConnection {

  private let channel: DispatchIO

  fileprivate init(socket: Int32) {
    channel = DispatchIO(type: .stream,
                         fileDescriptor: socket,
                         queue: DispatchQueue.main,
                         cleanupHandler: { error in
      Darwin.close(socket)
    })
    channel.setLimit(lowWater: 1)
    channel.setLimit(highWater: Int.max)
  }

  nonisolated func close() {
    channel.close(flags: .stop)
  }

  func read() -> AsyncThrowingStream<DispatchData, Error> {
    AsyncThrowingStream(bufferingPolicy: .unbounded) { continuation in
      continuation.onTermination = { [channel] reason in
        channel.close()
      }
      channel.read(offset: 0, length: Int.max, queue: DispatchQueue.main) { [channel] done, data, error in
        print("on data ready: \(data?.count ?? 0) bytes, done: \(done), error: \(error)")
        if error != 0 {
          continuation.finish(throwing: POSIXError(errno: error))
          channel.close(flags: .stop)
        } else if let data, !data.isEmpty {
          continuation.yield(data)
        }
        if done {
          continuation.finish()
        }
      }
    }
  }

  func write(_ str: String) async throws {
    let data = str.utf8CString.withUnsafeBytes { bytes in
      DispatchData(bytes: bytes)
    }
    try await write(data)
  }

  func write(_ data: DispatchData) async throws {
    try await withTaskCancellationHandler {
      let _: Void = try await withCheckedThrowingContinuation { continuation in
        channel.write(offset: 0, data: data, queue: DispatchQueue.main) { done, data, error in
          guard done else { return }

          if error == 0 {
            continuation.resume()
          } else {
            continuation.resume(throwing: POSIXError(errno: error))
          }
        }
      }
    } onCancel: {
      close()
    }
  }
}

extension IOListener {
  static func listen(socket: String) throws -> IOListener {
    let fd = try Bridge.bind(socket)
    if Darwin.listen(fd, 256) != 0 {
      throw POSIXError.errno
    }

    return IOListener(socket: fd, path: socket)
  }
}

extension IOConnection {

  static func connect(socket: String) throws -> IOConnection {
    // Ensure the socket does not exist
    let fd = try Bridge.connect(socket)
    return IOConnection(socket: fd)
  }

}
