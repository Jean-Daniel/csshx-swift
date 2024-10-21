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
  
  static let shell: String = getShell()

  private static func getShell() -> String {
    var userShell: String? = nil
    let defaults = UserDefaults(suiteName: TerminalBundleId)
    
    // Lookup for the window settings
    if let defaultProfile = defaults?.string(forKey: "Default Window Settings"),
       let settings = defaults?.dictionary(forKey: "Window Settings")?[defaultProfile] as? Dictionary<String, Any>,
       let runAsShell = settings["RunCommandAsShell"] as? Bool, runAsShell,
       let shell = settings["CommandString"] as? String {
      // remove leading '-' included by default by Terminal
      userShell = FilePath(shell).lastComponent?.string.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }
    
    // Then for the global terminal settings
    if (userShell?.isEmpty != false), let shell = defaults?.string(forKey: "Shell") {
      userShell = FilePath(shell).lastComponent?.string
    }
    
    // Then in passwd.
    if (userShell?.isEmpty != false) {
      if let passwd = getpwuid(getuid()) {
        userShell = FilePath(platformString: passwd.pointee.pw_shell).lastComponent?.string
      }
    }
    
    // And fallback to default shell
    if (userShell?.isEmpty != false) {
      userShell = "zsh"
    }
    return userShell!
  }
  
}
