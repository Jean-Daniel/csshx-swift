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
  struct HostCommand: ParsableCommand {

    struct Options: ParsableArguments {
      @Option var ssh: String
      @Option var socket: String
      @Option var hostname: String

      @Option var login: String? = nil
      @Option var port: UInt16? = nil

      @Option(parsing: .unconditionalSingleValue) var sshArgs: [String] = []

      @Argument(parsing:.postTerminator) var remoteCommand: [String] = []
    }

    @OptionGroup var options: Options

    func run() throws {
      // First, connect to the socket (no need to try to launch ssh if connection fails)
      logger.debug("trying to connect socket at path: \(options.socket)")
      let client = try SSHWrapper(socket: options.socket)

      // Then starts SSH
      try client.start(options: options)

      // Start listening for incoming data from master
      client.connection.read { data in
        for c in data {
          withUnsafePointer(to: c) { ptr in
            do {
              try Bridge.tiocsti(c)
            } catch {
              logger.error("tiocsti failed with error: \(error)")
              client.close()
            }
          }
        }
      } whenDone: { error in
        if let error {
          logger.error("socket read failed with error: \(error)")
        }
        // If connection closed, terminating
        client.close()
      }

      // If ssh exit, terminating
      waitFor(pid: client.pid) { result in
        if result != 0 {
          logger.info("ssh exit with status \(result)")
        } else {
          logger.info("ssh exit")
        }
        client.close()
      }
    }
  }
}

private class SSHWrapper {

  var pid: pid_t = 0

  let connection: DispatchIO

  init(socket: String) throws {
    let fd = try Bridge.connect(socket)
    self.connection = DispatchIO(type: .stream,
                                 fileDescriptor: fd,
                                 queue: DispatchQueue.main,
                                 cleanupHandler: { error in 
      Darwin.close(fd)
    })
    // We want to process data in real-time. Do not buffer input.
    self.connection.setLimit(lowWater: 1)
  }

  func close() {
    // Ensure ssh is terminated
    if (pid > 0) {
      kill(pid, SIGTERM)
      waitpid(pid, nil, 0)
    }
    // Terminate master connection
    connection.close(flags: .stop)
    // terminate the process (even if connection closing is not done)
    Foundation.exit(0)
  }

  func start(options: Csshx.HostCommand.Options) throws {
    var args: [String] = [options.ssh]
    if let login = options.login {
      args.append("-l")
      args.append(login)
    }

    if let port = options.port {
      args.append("-p")
      args.append(String(port))
    }
    args.append(contentsOf: options.sshArgs)
    args.append(options.hostname)

    args.append(contentsOf: options.remoteCommand)

    // Note: Do not use Process for 2 reasons:
    // - Process does many things under the hood, and end-up freezing the process in a call to tcsetattr().
    // - Process does not support looking for the target process in the PATH, which is something we want to be
    //   able to defaults to 'ssh' for the ssh command line.
    var pid: pid_t = 0
    let err = args.withCStrings { argv in
      posix_spawnp(&pid, args[0], nil, nil, argv, environ)
    }

    if (err < 0) {
      throw POSIXError.errno
    }

    self.pid = pid

    // Make sure to not mess up ssh output
    fclose(stdout)
    fclose(stderr)
  }
}
