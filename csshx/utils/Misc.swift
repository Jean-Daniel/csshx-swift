//
//  Misc.swift
//  csshx
//
//  Created by Jean-Daniel Dupas on 12/10/2023.
//

import Foundation
import RegexBuilder

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

func fwrite(str: String) {
  var data = str
  let _ = data.withUTF8 { ptr in
    fwrite(ptr.baseAddress, ptr.count, 1, stdout)
    fflush(stdout)
  }
}

struct stty {

  static func clear() { fwrite(str: "\u{001b}[1J\u{001b}[0;0H") }

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

func getBestLayout(for ratio: Double, hosts: Int, on screen: CGSize) -> (Int, Int) {
  var bestRowCount = 0
  var bestColumnCount = 0
  var bestRatioDelta = Double.infinity

  func testRatio(rows: Int, columns: Int) {
    let winRatio = (screen.width / Double(columns)) / (screen.height / Double(rows))
    let delta = ratio > winRatio ? ratio / winRatio : winRatio / ratio
    if delta < bestRatioDelta {
      bestRatioDelta = delta
      bestRowCount = rows
      bestColumnCount = columns
    }
  }

  switch hosts {
    case 0:
      return (0, 0)
    case 1:
      return (1, 1)
    case 2:
      testRatio(rows: 1, columns: 2)
      testRatio(rows: 2, columns: 1)
    case 3:
      // Special case for 3 to avoid wasting 1/4 of the screen space (2x2 layout)
      testRatio(rows: 1, columns: 3)
      testRatio(rows: 3, columns: 1)
    default:
      for rows in 1...Int(ceil(Float(hosts).squareRoot())) {
        // For each rows x columns
        let columns = Int(ceil(Float(hosts) / Float(rows)))
        // Test both horizontal and vertical layout
        testRatio(rows: rows, columns: columns)
        if rows != columns {
          testRatio(rows: columns, columns: rows)
        }
      }
  }

  return (bestRowCount, bestColumnCount)
}

