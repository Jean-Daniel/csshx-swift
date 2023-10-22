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

public extension Sequence {
  @inlinable
  func count(where predicate: (Element) throws -> Bool) rethrows -> Int {
    try reduce(0) { try predicate($1) ? $0 + 1 : $0 }
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

struct stty {

  static func clear() { print("\u{001b}[1J\u{001b}[0;0H") }

  @discardableResult
  static func set(attr: termios) throws -> termios {
    var current = termios()
    if (tcgetattr(STDIN_FILENO, &current) < 0) {
      throw POSIXError.errno
    }

    var t = attr
    if (tcsetattr(STDIN_FILENO, 0, &t) < 0) {
      throw POSIXError.errno
    }
    return current
  }

  // Replicate 'stty raw'
  static func raw() throws -> termios {
    var current = termios()
    if (tcgetattr(STDIN_FILENO, &current) < 0) {
      throw POSIXError.errno
    }

    var t = current
    // copied from stty sources
    cfmakeraw(&t)
    t.c_cflag &= ~UInt(CSIZE|PARENB)
    t.c_cflag |= UInt(CS8)

    if (tcsetattr(STDIN_FILENO, 0, &t) < 0) {
      throw POSIXError.errno
    }
    return current
  }
}

