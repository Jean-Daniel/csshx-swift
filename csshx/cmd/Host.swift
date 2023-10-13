//
//  Host.swift
//  csshx
//
//  Created by Jean-Daniel Dupas on 12/10/2023.
//

import Foundation
import ArgumentParser

extension Csshx {

  // Host does not try to read or parse settings file.
  // All values must be passed though launching options.
  struct Host: AsyncParsableCommand {

    @Option var ssh: String
    @Option var socket: String

    @Option var slaveid: Int

    @Argument var hostname: String
    @Argument(parsing:.postTerminator) var remoteCommand: [String] = []

    func run() async throws {
      // First, connect to the socket (no need to try to launch ssh if connection fails)
      let client = try IOConnection.connect(socket: socket)
      defer { client.close() }

      // Then starts SSH
      let pid = try await ssh()
      defer {
        // Ensure ssh is terminated
        kill(pid, SIGTERM)
        // waitpid(pid, nil, 0)
      }

      // Launch io loop and monitor ssh process.
      try await withThrowingTaskGroup(of: Void.self) { group in
        defer {
          group.cancelAll()
        }

        group.addTask {
          // start socket task
          try await ioloop(client)
        }

        group.addTask {
          // Start ssh and run until it exits
          let result = await waitFor(pid: pid)
          if result != 0 {
            print("ssh exit with status \(result)")
          }
        }

        // First finished child task wins, cancel the other task.
        try await group.next()
      }
    }

    private func ioloop(_ client: IOConnection) async throws {
      try await client.write("host \(slaveid)\n")
      // Read and dispatch input
      for try await data in client.read() {
        for c in data {
          try withUnsafePointer(to: c) { ptr in
            try Bridge.tiocsti(c)
          }
        }
      }
    }

    private func ssh() async throws -> pid_t {
      let (user, host, port) = try hostname.parseUserHostPort()

      var args: [String] = [ssh]
      if let user {
        args.append("-l")
        args.append(user)
      }

      if let port {
        args.append("-p")
        args.append(String(port))
      }

      args.append(host)
      args.append(contentsOf: remoteCommand)

      // Note: Process.run freeze when running in a tty due
      // to some termio interaction (tcsetattr call) -> use low-level primitive instead.
      var pid: pid_t = 0
      let err = args.withCStrings { argv in
        posix_spawnp(&pid, ssh, nil, nil, argv, environ)
      }

      if (err < 0) {
        throw POSIXError.errno
      }

      // Make sure to not mess up ssh output
      fclose(stdout)
      fclose(stderr)

      return pid
    }
  }
}
