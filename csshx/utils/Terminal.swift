//
//  Terminal.swift
//  csshx
//
//  Created by Jean-Daniel Dupas on 10/10/2023.
//

import Foundation

let TerminalBundleId = "com.apple.terminal"

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
      _shell = shell
    }
    
    // Then for the global terminal settings
    if (_shell?.isEmpty != false) {
      _shell = defaults?.string(forKey: "Shell")
    }
    
    // Then in passwd.
    if (_shell?.isEmpty != false) {
      if let passwd = getpwuid(getuid()) {
        _shell = String(cString: passwd.pointee.pw_shell)
      }
    }
    
    // And fallback to default shell
    if (_shell?.isEmpty != false) {
      _shell = "/bin/zsh"
    }
    
    return _shell!
  }

}
