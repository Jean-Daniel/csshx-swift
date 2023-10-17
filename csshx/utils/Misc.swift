//
//  Misc.swift
//  csshx
//
//  Created by Jean-Daniel Dupas on 12/10/2023.
//

import Foundation
import RegexBuilder

private let hostFormat = Regex {
  Optionally {
    Regex {
      Capture(OneOrMore(.any, .reluctant))
      "@"
    }
  }
  Capture(OneOrMore(.any, .reluctant))
  Optionally {
    Regex {
      ":"
      Capture {
        OneOrMore(.any)
      }
    }
  }
}

extension StringProtocol where Self.SubSequence == Substring {
  func parseUserHostPort() throws -> (String?, String, String?) {
    // Formats:
    //   hostname
    //   hostname:port
    //   user@hostname
    //   user@hostname:port
    guard let result = wholeMatch(of: hostFormat) else {
      throw CocoaError(.formatting)
    }
    return (result.output.1.flatMap(String.init), String(result.output.2), result.output.3.flatMap(String.init));
  }
}

extension Sequence where Element == String {

  @discardableResult
  func withCStrings<R>(body: (UnsafePointer<UnsafeMutablePointer<CChar>?>) throws -> R) rethrows -> R {
    let cstrings = map { strdup($0) } + [nil]
    defer {
      for ptr in cstrings {
        if let ptr = ptr { free(ptr) }
      }
    }

    return try body(cstrings)
  }
}

extension POSIXError {

  static var errno: POSIXError {
    POSIXError(errno: Darwin.errno)
  }

  init(errno: Int32) {
    self.init(POSIXErrorCode(rawValue: errno) ?? .EINVAL)
  }
}
