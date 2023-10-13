//
//  Host.swift
//  csshx
//
//  Created by Jean-Daniel Dupas on 12/10/2023.
//

import Foundation
import ArgumentParser

extension Launcher {
  struct Host: AsyncParsableCommand {

    @Option var socket: String

    @Option var slavehost: String
    @Option var slaveid: Int

    func run() async throws {
      let settings = loadSettings()

      // start socket task
      Task {
        try await ioloop(settings:settings)
      }

      // Start ssh and run until it exits
      let result = try await ssh(host: slavehost, settings: settings)
      if result != 0 {
        print("ssh exit with status \(result)")
      }
    }

    private func loadSettings() -> Settings {
      return Settings()
    }

    private func ioloop(settings: Settings) async throws {
//      try await Task.sleep(for: .seconds(2))
//      let data = "echo Hé 🐮\n".data(using: .utf8)!
//      for c in data {
//        try withUnsafePointer(to: c) { ptr in
//          try TTY.tiocsti(c)
//        }
//      }
      print("starting ioloop")
      guard let greeting = "slave \(slaveid) \(slavehost)\n".data(using: .utf8) else {
        throw POSIXError(.EINVAL)
      }

      let client = try await IOClient.connect(socket: socket)

      try await client.write(data: greeting)

      while (!Task.isCancelled) {
        // Read and dispatch input
        let data = try await client.read()
        for c in data {
          try withUnsafePointer(to: c) { ptr in
            try TTY.tiocsti(c)
          }
        }
      }
    }

    private func ssh(host hostname: String, settings: Settings) async throws -> Int32 {
      let (user, host, port) = try hostname.parseUserHostPort()

      var args = [settings.ssh]
      if let user = user ?? settings.login {
        args.append("-l")
        args.append(user)
      }

      if let port {
        args.append("-p")
        args.append(String(port))
      }

      args.append(host)

      //      if let cmd = settings.remoteCommand {
      //        // TODO: split and quote
      //        args.append(cmd)
      //      }

      print("\(args.joined(separator: " "))")

      var pid: pid_t = 0
      let err = args.withCStrings { argv in
        // Note: Process.run freeze when running in a tty due to some termio interaction (tcsetattr call)
        posix_spawnp(&pid, settings.ssh, nil, nil, argv, environ)
      }

      if (err < 0) {
        throw POSIXError(POSIXError.Code(rawValue: errno)!)
      }

      // Make sure to not messed up with ssh output
      fclose(stdout)
      fclose(stderr)

      await waitFor(pid: pid)
      return 0
    }
  }
}
