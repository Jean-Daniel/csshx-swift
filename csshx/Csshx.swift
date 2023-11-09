//
//  csshx.swift
//  csshx
//
//  Created by Jean-Daniel Dupas on 03/10/2023.
//

import ArgumentParser
import Foundation
import OSLog

let logger = Logger(subsystem: "com.xenonium.csshx", category: "main")

// Bootstrap class that start either the launcher, controller or host process.
@main
struct Csshx {
  // Simple hack to hide controller/host commands and options from the main tool.

  // To launch csshx in controller or host mode, use the following command:
  // csshx -- controller <options>
  // csshx -- host <options>

  static func main() throws {
    let args = CommandLine.arguments.dropFirst()
    if args.count >= 2, args[args.startIndex] == "--" {
      switch args[args.startIndex + 1] {
        case "controller":
          return ControllerCommand.main(argv: Array(args.dropFirst(2)))
        case "host":
          return HostCommand.main(argv: Array(args.dropFirst(2)))
        default:
          // Let the launcher fails with argument parsing and report error properly.
          break
      }
    }
    Launcher.main(argv: Array(args))
  }
}

extension ParsableCommand {
  // using 'argv' label to avoid conflict with ParsableCommand.main()
  fileprivate static func main(argv arguments: [String])  {
    do {
      var command = try parseAsRoot(arguments)
      try command.run()
    } catch {
      exit(withError: error)
    }
  }
}
