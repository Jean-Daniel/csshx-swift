//
//  csshx.swift
//  csshx
//
//  Created by Jean-Daniel Dupas.
//

import Foundation

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
          return ControllerCommand.main(Array(args.dropFirst(2)))
        case "host":
          return HostCommand.main(Array(args.dropFirst(2)))
        default:
          // Let the launcher fails with argument parsing and report error properly.
          break
      }
    }
    Launcher.main(Array(args))
  }
}
