//
//  Socket.swift
//  csshx
//
//  Created by Jean-Daniel Dupas on 12/10/2023.
//

import Foundation

class IOListener {
  
  private let path: String
  private let socket: Int32
  
  private var listening: DispatchSourceRead? = nil
  
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
  
  func startWaiting(_ handler: @escaping (Result<Int32, Error>) -> Void) {
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
        do {
          try Bridge.setNonBlocking(client_fd)
          handler(Result.success(client_fd))
        } catch {
          Darwin.close(client_fd)
          print("client connection setup failed with error: \(error)")
        }
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
    let fd = try Bridge.bind(socket, umask: 0o700)
    if Darwin.listen(fd, 256) != 0 {
      throw POSIXError.errno
    }

    return IOListener(socket: fd, path: socket)
  }
}

extension DispatchIO {

  func read(_ block: @escaping (DispatchData) -> Void, whenDone: @escaping (Error?) -> Void) {
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
  
  func write(_ data: DispatchData, whenDone: @escaping (Error?) -> Void) {
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

/*
 class IOConnection {

   private let channel: DispatchIO

   init(fd: Int32, closeFd: Bool = true) {
     channel = DispatchIO(type: .stream,
                          fileDescriptor: fd,
                          queue: DispatchQueue.main,
                          cleanupHandler: closeFd ? { error in Darwin.close(fd) } : { error in })
     // We want to process data in real-time. Do not buffer input.
     channel.setLimit(lowWater: 1)
   }

   func getPid() -> pid_t {
     var pid: pid_t = 0
     var pid_size = socklen_t(MemoryLayout.size(ofValue: pid))
     guard getsockopt(channel.fileDescriptor, SOL_LOCAL, LOCAL_PEERPID, &pid, &pid_size) == 0 else {
       logger.warning("failed to retreive socket pid: \(errno)")
       return 0
     }
     return pid
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
         if error == ECANCELED {
           continuation.finish()
         } else if error != 0 {
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

   func write(_ data: DispatchData, whenDone: @escaping (Error?) -> Void) {
     channel.write(offset: 0, data: data, queue: DispatchQueue.main) { done, data, error in
       guard done else { return }

       if error == 0 {
         whenDone(nil)
       } else {
         whenDone(POSIXError(errno: error))
       }
     }
   }
 }
 */
