//
//  HostWIndow.swift
//  csshx
//
//  Created by Jean-Daniel Dupas on 24/10/2023.
//

import Foundation

class HostWindow: Equatable {

  let tab: Terminal.Tab
  let host: Target
  let tty: dev_t

  // Terminal Tab + Socket Connection
  var whenDone: ((Error?) -> Void)? = nil
  var connection: DispatchIO? = nil

  var enabled: Bool = true

  init(tab: Terminal.Tab, host: Target, tty: dev_t) {
    self.tab = tab
    self.host = host
    self.tty = tty
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
