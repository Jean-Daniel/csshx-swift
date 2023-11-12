//
//  Socket.swift
//  csshx
//
//  Created by Jean-Daniel Dupas.
//

import Foundation

class IOListener {
  
  private let path: String
  private let socket: Int32
  
  private var listening: (any DispatchSourceRead)? = nil
  
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
    if let listening {
      listening.cancel()
    } else {
      _close()
    }
  }
  
  func startWaiting(_ handler: @escaping (Result<Int32, any Error>) -> Void) {
    guard listening == nil else {
      return
    }
    
    let source = DispatchSource.makeReadSource(fileDescriptor: socket, queue: .main)
    listening = source
    
    source.setEventHandler { [socket] in
      var client_addr = sockaddr()
      var client_addrlen = UInt32(MemoryLayout.size(ofValue: client_addr))
      let client_fd = Darwin.accept(socket, &client_addr, &client_addrlen)
      if (client_fd < 0) {
        handler(Result.failure(POSIXError.errno))
      } else {
        handler(Result.success(client_fd))
      }
    }
    source.setCancelHandler {
      self._close()
    }
    
    source.activate()
  }
}

extension IOListener {
  static func listen(socket: String) throws -> IOListener {
    let fd = try Socket.bind(socket, umask: 0o077)
    if Darwin.listen(fd, 256) != 0 {
      throw POSIXError.errno
    }
    
    return IOListener(socket: fd, path: socket)
  }
}

extension DispatchIO {
  
  func read(_ block: @escaping (DispatchData) -> Void, whenDone: @escaping ((any Error)?) -> Void) {
    read(offset: 0, length: .max, queue: .main) { [self] done, data, error in
      if error == ECANCELED {
        whenDone(nil)
      } else if error != 0 {
        whenDone(POSIXError(errno: error))
        close(flags: .stop)
      } else if let data, !data.isEmpty {
        block(data)
      }
      if done {
        whenDone(nil)
      }
    }
  }
  
  func write(_ data: DispatchData, whenDone: @escaping ((any Error)?) -> Void) {
    write(offset: 0, data: data, queue: .main) { done, data, error in
      guard done else {
        // Ignore partial write
        return
      }
      
      if error == 0 {
        whenDone(nil)
      } else {
        whenDone(POSIXError(errno: error))
      }
    }
  }
}

