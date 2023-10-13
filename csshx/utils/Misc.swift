//
//  Misc.swift
//  csshx
//
//  Created by Jean-Daniel Dupas on 12/10/2023.
//

import Foundation
import RegexBuilder

private let anythingButAt: CharacterClass = .anyOf("@").inverted
private let anythingButColon: CharacterClass = .anyOf(":").inverted

private let hostFormat = Regex {
  Optionally {
    Regex {
      Capture {
        OneOrMore(anythingButAt)
      }
      "@"
    }
  }
  Capture {
    OneOrMore(anythingButColon)
  }
  Optionally {
    Regex {
      ":"
      Capture {
        OneOrMore(.digit)
      } transform: { UInt16($0)! }
    }
  }
}

extension String {
  func parseUserHostPort() throws -> (String?, String, UInt16?) {
    // Formats:
    //   hostname
    //   hostname:port
    //   user@hostname
    //   user@hostname:port
    guard let result = wholeMatch(of: hostFormat) else {
      throw CocoaError(.formatting)
    }
    return (result.output.1.flatMap(String.init), String(result.output.2), result.output.3);
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
