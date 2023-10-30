//
//  HostWIndow.swift
//  csshx
//
//  Created by Jean-Daniel Dupas on 24/10/2023.
//

import Foundation

class HostWindow: Equatable {

  struct Config {
    var selectedTextColor: Terminal.Color?
    var selectedBackgroundColor: Terminal.Color = Terminal.Color(red: 17990, green: 35209, blue: 53456)

    var disabledTextColor: Terminal.Color = Terminal.Color(red: 37779, green: 37779, blue: 37779)
    var disabledBackgroundColor: Terminal.Color?
  }

  let tab: Terminal.Tab
  let config: Config
  let host: Target
  let tty: dev_t

  // Terminal Tab + Socket Connection
  var whenDone: ((Error?) -> Void)? = nil
  var connection: DispatchIO? = nil

  var enabled: Bool = true {
    didSet {
      setColors()
    }
  }

  var disabled: Bool { !enabled }

  var selected: Bool = false {
    didSet {
      setColors()
    }
  }

  init(tab: Terminal.Tab, host: Target, tty: dev_t, config: Config) {
    self.tab = tab
    self.host = host
    self.tty = tty
    self.config = config
  }

  private func setColors() {
    if selected {
      tab.setTextColor(color: config.selectedTextColor)
      tab.setBackgroundColor(color: config.selectedBackgroundColor)
    } else if disabled {
      tab.setTextColor(color: config.disabledTextColor)
      tab.setBackgroundColor(color: config.disabledBackgroundColor)
    } else {
      tab.setTextColor(color: nil)
      tab.setBackgroundColor(color: nil)
    }
  }

  func terminate() {
    connection?.close(flags: .stop)
    connection = nil
    enabled = false
    // Closing window in case the profile does not close window automatically
    // tab.close()
  }

  static func == (lhs: HostWindow, rhs: HostWindow) -> Bool {
    return lhs.host == rhs.host && lhs.tab == rhs.tab
  }
}

extension HostWindow: CustomStringConvertible {
  var description: String {
    if let port = host.port {
      return "\(host.hostname):\(port)"
    }
    return host.hostname
  }
}
