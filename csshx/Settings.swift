//
//  Settings.swift
//  csshx
//
//  Created by Jean-Daniel Dupas on 09/10/2023.
//

import Foundation
import RegexBuilder

protocol ExpressibleByStringArgument {
  /// Creates a new instance of this type from a command-line-specified
  /// argument.
  init?(argument: String)
}

extension Bool: ExpressibleByStringArgument {}
extension Int: ExpressibleByStringArgument {}
extension Int32: ExpressibleByStringArgument {}
extension String: ExpressibleByStringArgument {}
// Using CGFloat for convenience, but still accepting only integer
extension CGFloat: ExpressibleByStringArgument {
  init?(argument: String) {
    guard let value = Int(argument: argument) else { return nil }
    self.init(value)
  }
}

extension Array<Int>: ExpressibleByStringArgument {

  init?(argument: String) {
    guard let indices = Self.parse(ranges: argument) else {
      return nil
    }
    self.init(indices)
  }

  private static func parse(ranges: String) -> IndexSet? {
    // split on comma, and then parse individual range if they contains '-'
    if ranges.contains(",") {
      var result = IndexSet()
      for range in ranges.split(separator: ",") {
        guard parse(range: String(range), into: &result) else {
          return nil
        }
      }
      return result
    }

    // single range or single value
    var result = IndexSet()
    guard parse(range: ranges, into: &result) else {
      return nil
    }
    return result
  }

  private static let intRange = Regex {
    Capture(OneOrMore(.digit)) { Int($0)! }
    "-"
    Capture(OneOrMore(.digit)) { Int($0)! }
  }

  // start-end
  private static func parse(range: String, into: inout IndexSet) -> Bool {
    // single word -> return change unchanged.
    if range.wholeMatch(of: OneOrMore(.digit)) != nil {
      guard let value = Int(range) else {
        return false
      }
      into.insert(value)
      return true
    } else if let match = range.wholeMatch(of: Self.intRange) {
      let start = match.output.1
      let end = match.output.2
      guard start < end else {
        logger.debug("invalid range. start must be less than end: \(range)")
        return false
      }
      into.insert(integersIn: start...end)
      return true
    }

    return false
  }
}


// MARK: CGRect

private let boundsValueRegex = Regex {
  ZeroOrMore(.whitespace)
  Capture {
    Repeat(.digit, count: 2)
  } transform: { CGFloat(Int($0)!) }
  ZeroOrMore(.whitespace)
}

private let boundsRegex = Regex {
  Anchor.startOfLine
  ZeroOrMore(.whitespace)
  "{"
  boundsValueRegex
  ","
  boundsValueRegex
  ","
  boundsValueRegex
  ","
  boundsValueRegex
  "}"
  ZeroOrMore(.whitespace)
  Anchor.endOfLine
}

extension CGRect: ExpressibleByStringArgument {
  init?(argument: String) {
    guard let bounds = argument.wholeMatch(of: boundsRegex) else {
      return nil
    }
    self.init(origin: CGPoint(x: bounds.output.1, y: bounds.output.2),
              size: CGSize(width: bounds.output.3, height: bounds.output.4))
  }
}

enum SettingsError: Error {
  case invalidValue
}

struct Op {

  private let op: (inout Settings, String) throws -> Void

  @inlinable
  func callAsFunction(settings: inout Settings, value: String) throws {
    try op(&settings, value)
  }

  static func set<Ty>(_ keypath: WritableKeyPath<Settings, Ty>) -> Op where Ty: ExpressibleByStringArgument {
    return Op { $0[keyPath: keypath] = try parse($1) }
  }

  static func set<Ty>(_ keypath: WritableKeyPath<Settings, Ty?>) -> Op where Ty: ExpressibleByStringArgument {
    return Op { $0[keyPath: keypath] = try parse($1) }
  }

//  static func append<Ty>(_ keypath: WritableKeyPath<Settings, [Ty]>) -> Op where Ty: ExpressibleByStringArgument {
//    return Op {
//      $0[keyPath: keypath].append(try parse($1))
//    }
//  }
}

private func parse<Ty>(_ value: String) throws -> Ty where Ty: ExpressibleByStringArgument {
  guard let v = Ty(argument: value) else {
    throw SettingsError.invalidValue
  }
  return v
}

// {65535,3243,16534}
private let intValueRegex = Regex {
  Capture {
    OneOrMore(.digit)
  } transform: { UInt16($0) }
}

private let rgbColorRegex = Regex {
  Anchor.startOfLine
  "{"
  intValueRegex
  ","
  intValueRegex
  ","
  intValueRegex
  "}"
  Anchor.endOfLine
}

// (#)0a413b
private let hexInt = Regex {
  Capture {
    One(.hexDigit)
    One(.hexDigit)
  } transform: { UInt16($0, radix: 16) }
}

private let hexColorRegex = Regex {
  Anchor.startOfLine
  Optionally("#")
  hexInt
  hexInt
  hexInt
  Anchor.endOfLine
}

extension Terminal.Color: ExpressibleByStringArgument {
  init?(argument: String) {
    if let rgb = argument.wholeMatch(of: rgbColorRegex) {
      guard let r = rgb.output.1, let g = rgb.output.2, let b = rgb.output.3 else {
        logger.warning("invalid color string: \(argument)")
        return nil
      }
      self.init(red: CGFloat(r) / 65535, green: CGFloat(g) / 65535, blue: CGFloat(b) / 65535)
    } else if let hex = argument.wholeMatch(of: hexColorRegex) {
      guard let r = hex.output.1, let g = hex.output.2, let b = hex.output.3 else {
        logger.warning("invalid color string: \(argument)")
        return nil
      }
      self.init(red: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255)
    } else {
      logger.warning("invalid color string: \(argument)")
      return nil
    }
  }

  // using terminal colors
  init(red: Int, green: Int, blue: Int) {
    self.red = CGFloat(red) / 65535
    self.green = CGFloat(green) / 65535
    self.blue = CGFloat(blue) / 65535
  }
}

struct EscapeSequence: ExpressibleByStringArgument {
  let value: UInt8
  let ascii: String

  init?(argument: String) {
    guard let match = argument.wholeMatch(of: EscapeSequence.regex),
          let value = match.output.1 else {
      return nil
    }
    self.value = value
    self.ascii = String(Unicode.Scalar(value + 64))
  }

  private static let regex = Regex {
    "\\"
    Capture(Repeat("0"..."7", count: 3)) {
      UInt8($0, radix: 8)
    }
  }
}

// MARK: - Settings
struct Settings {

  var dummy: Bool = false
  // Windows Layout
  var space: Int32 = -1

  var layout = WindowLayoutManager.Config()
  var hostWindow = HostWindow.Config()

  var actionKey: EscapeSequence = EscapeSequence(argument: "\\001")!

  var controllerTextColor: Terminal.Color? = Terminal.Color(red: 65535, green: 65535, blue: 65535)
  var controllerBackground: Terminal.Color? = Terminal.Color(red: 38036, green: 0, blue: 0)

  var resizingTextColor: Terminal.Color?
  var resizingBackgroundColor: Terminal.Color? = Terminal.Color(red: 17990, green: 35209, blue: 53456)

  // SSH
  var sshArgs: String? = nil
  var remoteCommand: String? = nil

  var login: String?

  var debug: Bool = false
  var sessionMax = 256

  var pingTest: Bool = false
  var pingTimeout: Int = 2

  var socket: String? = nil

  var ssh: String = "ssh"
  var interleave: Int = 0

  var controllerWindowProfile: String? = nil
  var hostWindowProfile: String? = nil

  var sortHosts: Bool = false

  mutating func set(_ arg: String, value: String) throws {
    guard let op = Self.arguments[arg] else {
      throw POSIXError(.EINVAL)
    }
    try op(settings: &self, value: value)
  }
}


extension Settings {
  static let arguments : [String: Op] = [
    // Common settings
    "debug": .set(\Settings.debug),

    // Launcher settings
    "master_settings_set": .set(\Settings.controllerWindowProfile),
    "controller_window_profile": .set(\Settings.controllerWindowProfile),

    // Controller specific settings
    "action_key": .set(\Settings.actionKey),

    "slave_settings_set": .set(\Settings.hostWindowProfile),
    "host_window_profile": .set(\Settings.hostWindowProfile),

    "color_master_foreground": .set(\Settings.controllerTextColor),
    "color_controller_text": .set(\Settings.controllerTextColor),
    "color_master_background": .set(\Settings.controllerBackground),
    "color_controller_background": .set(\Settings.controllerBackground),

    "color_setbounds_foreground": .set(\Settings.resizingTextColor),
    "color_setbounds_background": .set(\Settings.resizingBackgroundColor),

    "color_selected_foreground": .set(\Settings.hostWindow.selectedTextColor),
    "color_selected_background": .set(\Settings.hostWindow.selectedBackgroundColor),

    "color_disabled_foreground": .set(\Settings.hostWindow.disabledTextColor),
    "color_disabled_background": .set(\Settings.hostWindow.disabledBackgroundColor),

    "sock": .set(\Settings.socket),
    "socket": .set(\Settings.socket),

    // SSH Session
    "ssh": .set(\Settings.ssh),
    "login": .set(\Settings.login),
    "ssh_args": .set(\Settings.sshArgs),
    "remote_command": .set(\Settings.remoteCommand),

    "session_max": .set(\Settings.sessionMax),
    "ping_test": .set(\Settings.pingTest),
    "ping_timeout": .set(\Settings.pingTimeout),

    // Hosts loading
    "sorthosts": .set(\Settings.sortHosts),
    "interleave": .set(\Settings.interleave),

    // Screen Layout
    "space": .set(\Settings.space),

    "tile_x": .set(\Settings.layout.columns),
    "columns": .set(\Settings.layout.columns),
    "tile_y": .set(\Settings.layout.rows),
    "rows": .set(\Settings.layout.rows),

//    "screen": .set(\Settings.layout.screens),
//    "screens": .set(\Settings.layout.screens),
    "screen_bounds": .set(\Settings.layout.screenBounds),

    "master_height": .set(\Settings.layout.controllerHeight),
    "controller_height": .set(\Settings.layout.controllerHeight),
  ]
}

