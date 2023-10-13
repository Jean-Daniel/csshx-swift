//
//  Socket.swift
//  csshx
//
//  Created by Jean-Daniel Dupas on 12/10/2023.
//

import Foundation
import Network

actor IOClient {

  private let connection: NWConnection

  fileprivate init(_ con: NWConnection) {
    connection = con
  }

  func close() {
    connection.cancel()
  }
  
  func read() async throws -> Data {
    try await withTaskCancellationHandler {
      try await withCheckedThrowingContinuation { continuation in
        connection.receive(minimumIncompleteLength: 1, maximumLength: Int.max) { content, contentContext, isComplete, error in
          if let error {
            continuation.resume(throwing: error)
          } else if let content {
            continuation.resume(returning: content)
          } else {
            continuation.resume(throwing: NWError.posix(.EIO))
          }
        }
      }
    } onCancel: {
      connection.cancel()
    }
  }

  func write(data: Data) async throws {
    try await withTaskCancellationHandler {
      let _: Void = try await withCheckedThrowingContinuation { continuation in
        connection.send(content: data, completion: .contentProcessed({ error in
          if let error = error {
            continuation.resume(throwing: error)
          } else {
            continuation.resume()
          }
        }))
      }
    } onCancel: {
      connection.cancel()
    }
  }
}

extension IOClient {

  static func connect(socket: String) async throws -> IOClient {
    let endpoint = NWEndpoint.unix(path: socket)
    let connection = NWConnection(to: endpoint, using: NWParameters())
    
    try await withTaskCancellationHandler {
      try await withCheckedThrowingContinuation { continuation in
        connection.stateUpdateHandler = { state in
          print("connection state: \(state)")
          switch (state) {
            case .setup:
              break
            case .waiting(_):
              break
            case .preparing:
              break
            case .ready:
              continuation.resume()
            case .failed(let error):
              continuation.resume(throwing: error)
            case .cancelled:
              connection.cancel()
            @unknown default:
              break
          }
        }
        print("starting connection")
        connection.start(queue: DispatchQueue.main)
      }
    } onCancel: {
      connection.cancel()
    }

    try Task.checkCancellation()
    return IOClient(connection)
  }

}
