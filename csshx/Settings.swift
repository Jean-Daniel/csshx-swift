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

// MARK: Color
struct Color: Sendable {
  let red: CGFloat
  let green: CGFloat
  let blue: CGFloat
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

extension Color: ExpressibleByStringArgument {
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

  var actionKey: EscapeSequence = EscapeSequence(argument: "\\001")!

  var selectedForeground: Color?
  var selectedBackground: Color? = Color(red: 17990, green: 35209, blue: 53456)

  var disabledForeground: Color? = Color(red: 37779, green: 37779, blue: 37779)
  var disabledBackground: Color?

  var controllerForeground: Color? = Color(red: 65535, green: 65535, blue: 65535)
  var controllerBackground: Color? = Color(red: 38036, green: 0, blue: 0)

  var resizingForeground: Color?
  var resizingBackground: Color? = Color(red: 17990, green: 35209, blue: 53456)

  var controllerHeight: Int = 87 // Pixels ?
  var screenBounds: CGRect? = nil

  var rows: Int = 0
  var columns: Int = 0

  var sshArgs: String? = nil
  var remoteCommand: String? = nil

  var login: String?
  var screen: Int = 0
  var space: Int32 = -1
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

    "color_master_foreground": .set(\Settings.controllerForeground),
    "color_controller_foreground": .set(\Settings.controllerForeground),
    "color_master_background": .set(\Settings.controllerBackground),
    "color_controller_background": .set(\Settings.controllerBackground),

    "color_setbounds_foreground": .set(\Settings.resizingForeground),
    "color_setbounds_background": .set(\Settings.resizingBackground),

    "color_selected_foreground": .set(\Settings.selectedForeground),
    "color_selected_background": .set(\Settings.selectedBackground),

    "color_disabled_foreground": .set(\Settings.disabledForeground),
    "color_disabled_background": .set(\Settings.disabledBackground),

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
    "tile_x": .set(\Settings.columns),
    "columns": .set(\Settings.columns),
    "tile_y": .set(\Settings.rows),
    "rows": .set(\Settings.rows),

    "screen_bounds": .set(\Settings.screenBounds),
    "screen": .set(\Settings.screen),
    "space": .set(\Settings.space),

    "master_height": .set(\Settings.controllerHeight),
    "controller_height": .set(\Settings.controllerHeight),
  ]
}

