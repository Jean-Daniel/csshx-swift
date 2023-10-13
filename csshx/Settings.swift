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

struct Arg {
  init<Ty>(_ keypath: WritableKeyPath<Settings, Ty>) where Ty: ExpressibleByStringArgument{
    self.setter = {
      $0[keyPath: keypath] = try parse($1)
    }
  }

  init<Ty>(_ keypath: WritableKeyPath<Settings, Ty?>) where Ty: ExpressibleByStringArgument{
    self.setter = {
      $0[keyPath: keypath] = try parse($1)
    }
  }

  fileprivate let setter: (inout Settings, String) throws -> Void
}

private func parse<Ty>(_ value: String) throws -> Ty where Ty: ExpressibleByStringArgument {
  if let i = Ty(argument: "") {
    return i
  }
  throw SettingsError.invalidValue
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

// MARK: - Settings
struct Settings {

  var actionKey: String = "\\001"

  var selectedForeground: Color?
  var selectedBackground: Color? = Color(red: 17990, green: 35209, blue: 53456)

  var disabledForeground: Color? = Color(red: 37779, green: 37779, blue: 37779)
  var disabledBackground: Color?

  var controllerForeground: Color? = Color(red: 65535, green: 65535, blue: 65535)
  var controllerBackground: Color? = Color(red: 38036, green: 0, blue: 0)

  var setboundsForeground: Color?
  var setboundsBackground: Color? = Color(red: 17990, green: 35209, blue: 53456)

  var controllerHeight: Int = 87 // Pixels ?
  var screenBounds: CGRect? = nil

  var rows: Int = 0
  var columns: Int = 0

  var sshArgs: String? = nil
//  remote_command
//  launchpid
  var login: String?
  var screen: Int = 0
  var space: Int32 = -1
  var debug: Int = 0
  var sessionMax = 256

  var pingTest: String? = nil
  var pingTimeout: Int = 2
//  slavehost
//  slaveid
  var socket: String = ""

  var ssh: String = "ssh"
  var interleave: Int = 0

  var controllerSettingsSet: String? = nil
  var hostSettingsSet: String? = nil

  var sorthosts: Bool = false

  fileprivate mutating func set(_ arg: Arg, value: String) throws {
    try arg.setter(&self, value)
  }
}


extension Settings {
  static let arguments : [String: Arg] = [
    "action_key": Arg(\Settings.actionKey),

    "color_selected_foreground": Arg(\Settings.selectedForeground),
    "color_selected_background": Arg(\Settings.selectedBackground),

    "color_disabled_foreground": Arg(\Settings.disabledForeground),
    "color_disabled_background": Arg(\Settings.disabledBackground),

    "color_master_foreground": Arg(\Settings.controllerForeground),
    "color_master_background": Arg(\Settings.controllerBackground),

    "color_setbounds_foreground": Arg(\Settings.setboundsForeground),
    "color_setbounds_background": Arg(\Settings.setboundsBackground),

    "tile_x": Arg(\Settings.columns),
    "tile_y": Arg(\Settings.rows),

    "ssh_args": Arg(\Settings.sshArgs),

//    "remote_command": \Settings.,
//    "launchpid": \Settings.,
    "login": Arg(\Settings.login),

    "master_height": Arg(\Settings.controllerHeight),
    "screen_bounds": Arg(\Settings.screenBounds),
    "screen": Arg(\Settings.screen),
    "space": Arg(\Settings.space),
    "debug": Arg(\Settings.debug),

//    "slavehost": \Settings.setboundsForeground,
//    "slaveid": \Settings.setboundsForeground,
    "sock": Arg(\Settings.socket),

    "session_max": Arg(\Settings.sessionMax),
    "ping_test": Arg(\Settings.pingTest),
    "ping_timeout": Arg(\Settings.pingTimeout),
    "ssh": Arg(\Settings.ssh),
    "interleave": Arg(\Settings.interleave),
    
    "master_settings_set": Arg(\Settings.controllerSettingsSet),
    "slave_settings_set": Arg(\Settings.hostSettingsSet),

    "sorthosts": Arg(\Settings.sorthosts),
  ]
}

