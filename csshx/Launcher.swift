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


@main
struct Launcher {
  // Simple hack to hide controller/host commands and options from the main tool.

  // To launch csshx in controller or host mode, use the following command:
  // csshx -- controller <options>
  // csshx -- host <options>

  static func main() async throws {
    let args = CommandLine.arguments.dropFirst()
    if args.count > 2, args[args.startIndex] == "--" {
      switch args[args.startIndex.advanced(by: 1)] {
        case "controller":
          return await Controller._main(Array(args.dropFirst(2)))
        case "host":
          return await Host._main(Array(args.dropFirst(2)))
        default:
          break
      }
    }
    await CsshX._main(Array(args))
  }
}

extension AsyncParsableCommand {
  fileprivate static func _main(_ arguments: [String]) async {
    do {
      var command = try parseAsRoot(arguments)
      if var asyncCommand = command as? AsyncParsableCommand {
        try await asyncCommand.run()
      } else {
        try command.run()
      }
    } catch {
      exit(withError: error)
    }
  }
}



// MARK: - Helper Functions



