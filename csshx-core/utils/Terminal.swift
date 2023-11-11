//
//  Terminal.swift
//  csshx
//
//  Created by Jean-Daniel Dupas.
//

import Foundation
import System

let TerminalBundleId = "com.apple.Terminal"

struct Terminal {

  private static var _shell: String? = nil

  static var shell: String {
    if let shell = _shell {
      return shell
    }
    
    let defaults = UserDefaults(suiteName: TerminalBundleId)
    
    // Lookup for the window settings
    if let defaultProfile = defaults?.string(forKey: "Default Window Settings"),
       let settings = defaults?.dictionary(forKey: "Window Settings")?[defaultProfile] as? Dictionary<String, Any>,
       let runAsShell = settings["RunCommandAsShell"] as? Bool, runAsShell,
       let shell = settings["CommandString"] as? String {
      // remove leading '-' included by default by Terminal
      _shell = FilePath(shell).lastComponent?.string.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }
    
    // Then for the global terminal settings
    if (_shell?.isEmpty != false), let shell = defaults?.string(forKey: "Shell") {
      _shell = FilePath(shell).lastComponent?.string
    }
    
    // Then in passwd.
    if (_shell?.isEmpty != false) {
      if let passwd = getpwuid(getuid()) {
        _shell = FilePath(platformString: passwd.pointee.pw_shell).lastComponent?.string
      }
    }
    
    // And fallback to default shell
    if (_shell?.isEmpty != false) {
      _shell = "zsh"
    }
    return _shell!
  }

}
