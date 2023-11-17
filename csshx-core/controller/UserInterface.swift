//
//  UserInterface.swift
//  csshx
//
//  Created by Jean-Daniel Dupas.
//

import Foundation
import RegexBuilder
import System

// Special match operator that consume
private func ~= (pattern: String, value: inout [UInt8]) -> Bool {
  guard !value.isEmpty, !pattern.isEmpty else { return false }
  
  if pattern.utf8.count == 1 {
    // Fast path
    if value[0] == pattern.utf8.first {
      value.removeFirst()
      return true
    }
    return false
  }
  
  if value.prefix(pattern.utf8.count).elementsEqual(pattern.utf8) {
    value.removeFirst(pattern.utf8.count)
    return true
  }
  return false
}

private func ~= (pattern: UInt8, value: inout [UInt8]) -> Bool {
  guard !value.isEmpty else { return false }
  
  if pattern == value[0] {
    value.removeFirst()
    return true
  }
  return false
}

extension Array<UInt8> {
  // TODO: other escape sequences
  mutating func dropEscapeSequence() -> Bool {
    guard !isEmpty else { return false }
    
    if self[0] == 0x5B {
      // CSI escape sequence.
      removeFirst()
      
      // Not sure about how to process it accurately. Dropping everything in range of supported CSI chars.
      trimPrefix { (0x20...0x7E).contains($0) }
      return true
    }
    return false
  }
}

protocol InputModeProtocol: Equatable, Identifiable<String> {
  var raw: Bool { get }
  
  mutating func prompt(_ ctrl :Controller) -> String
  mutating func onEnable(_ ctrl :Controller) throws -> Void
  mutating func parse(input: inout [UInt8], _ ctrl :Controller) throws -> (any InputModeProtocol)?
}

extension InputModeProtocol {
  func beep() {
    fwrite(str: "\u{007}", file: stdout)
  }
  
  static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.id == rhs.id
  }
}

// MARK: - Input Modes
struct InputMode {}

// MARK: -
extension InputMode {
  struct Starting: InputModeProtocol {
    
    var id: String { "starting" }
    
    var raw: Bool { true }
    
    func prompt(_ ctrl: Controller) -> String {
      "Starting hosts: \(ctrl.hosts.count { $0.connection != nil } )/\(ctrl.hosts.count)…\r\n"
    }
    
    func onEnable(_ ctrl: Controller) throws {
      // noop
    }
    
    func parse(input: inout [UInt8], _ ctrl: Controller) throws -> (any InputModeProtocol)? {
      // Discarding all input until ready.
      input.removeAll()
      return nil
    }
  }
}

// MARK: -
extension InputMode {
  
  struct Input: InputModeProtocol {
    
    var id: String { "input" }
    
    var raw: Bool { true }
    
    func prompt(_ ctrl: Controller) -> String {
      "Input to terminal: (Ctrl-\(ctrl.settings.actionKey.ascii) to enter control mode)\r\n"
    }
    
    func onEnable(_ ctrl: Controller) throws {
      // noop
    }
    
    func parse(input: inout [UInt8], _ ctrl: Controller) throws -> (any InputModeProtocol)? {
      // In input mode, data is always fully consummed.
      let action = ctrl.settings.actionKey
      // Convert CSI to SS3 cursor codes
      // \e[(A-D) -> \eO(A-D)
      //    if data.count >= 3 && data.starts(with: [ 27, 91 ]) && (65...68).contains(data[2]) {
      //      data[1] = 79
      //    }
      
      if let escape = input.firstIndex(of: action.value) {
        // Send data until escape sequence.
        if (escape > 0) {
          ctrl.send(bytes: input[0..<escape])
          // drop sent data + escape sequence
          input.removeSubrange(0...escape)
        } else {
          input.removeFirst()
        }
        // Switch mode
        return InputMode.Action()
      } else {
        // Forward all
        ctrl.send(bytes: input)
        input.removeAll()
      }
      return nil
    }
  }
}

// MARK: -
extension InputMode {
  
  struct Action: InputModeProtocol {
    
    var id: String { "action" }
    
    var raw: Bool { true }
    
    func prompt(_ ctrl: Controller) -> String {
      let escape = "Ctrl-\(ctrl.settings.actionKey.ascii)"
      
      return "Actions (Esc to exit, \(escape) to send \(escape) to input)\r\n" +
      "[c]reate window, [r]etile, s[o]rt, [e]nable/disable input, e[n]able all, " +
      // If there is a single host enable, add the 'select next' option.
      (ctrl.hosts.count > 1 && ctrl.hosts.count(where: { $0.enabled }) == 1 ? "[Space] Enable next " : "") +
      "[t]oggle enabled, [m]inimise, [h]ide, [s]end text, change [b]ounds, " +
      "change [g]rid, e[x]it\r\n";
    }
    
    func onEnable(_ ctrl: Controller) throws {
      // noop
    }
    
    func parse(input: inout [UInt8], _ ctrl: Controller) throws -> (any InputModeProtocol)? {
      if ctrl.settings.actionKey.value ~= input {
        ctrl.send(bytes: [ctrl.settings.actionKey.value])
        return InputMode.Input()
      }
      
      // create window
      else if "c" ~= input {
        return InputMode.AddHost()
      }
      
      // retile
      else if "r" ~= input {
        ctrl.layout()
        return InputMode.Input()
      }
      
      // sort
      else if "o" ~= input {
        return InputMode.Sort()
      }
      
      // enable/disable input
      else if "e" ~= input {
        return InputMode.Enable()
      }
      
      // enable all
      else if "n" ~= input {
        ctrl.hosts.forEach {
          $0.tab.window.zoomed = false
          $0.enabled = true
        }
        return InputMode.Input()
      }
      
      // toggle enabled
      else if "t" ~= input {
        ctrl.hosts.forEach {
          $0.tab.window.zoomed = false
          $0.enabled = !$0.enabled
        }
        return InputMode.Input()
      }
      
      // Minimize
      else if "m" ~= input {
        ctrl.hosts.forEach { $0.tab.miniaturize() }
        return InputMode.Input()
      }
      
      // Hide
      else if "h" ~= input {
        ctrl.hosts.forEach { $0.tab.hide() }
        return InputMode.Input()
      }
      
      // Send Text
      else if "s" ~= input {
        return InputMode.SendString()
      }
      
      // Change bounds
      else if "b" ~= input {
        return InputMode.Bounds()
      }
      
      // Switch to grid mode
      else if "g" ~= input {
        return InputMode.Grid()
      }
      
      else if " " ~= input, ctrl.hosts.count > 1, ctrl.hosts.count(where: { $0.enabled }) == 1 {
        if let idx = ctrl.hosts.firstIndex(where: { $0.enabled }) {
          ctrl.hosts[idx].enabled = false
          ctrl.hosts[(idx + 1) % ctrl.hosts.count].enabled = true
        }
        return InputMode.Input()
      }
      // exit
      else if "x" ~= input {
        ctrl.close()
      } else if 0x1b ~= input {
        // escape (\e)
        
        if input.dropEscapeSequence() {
          // if is escape sequence -> delete it and beep.
          beep()
          return nil
        } else {
          // else switch to input mode
          return InputMode.Input()
        }
      } else {
        input.removeAll()
        beep()
      }
      return nil
    }
  }
}

// MARK: -
extension InputMode {
  
  struct SendString: InputModeProtocol {
    
    var id: String { "send-string" }
    
    var raw: Bool { true }
    
    func prompt(_ ctrl: Controller) -> String {
      "Send string to all active windows: (Esc to exit)\r\n" +
      "[h]ostname, [c]onnection string, window [i]d\r\n"
    }
    
    func onEnable(_ ctrl: Controller) throws {
      
    }
    
    func parse(input: inout [UInt8], _ ctrl: Controller) throws -> (any InputModeProtocol)? {
      // hostname
      if "h" ~= input {
        ctrl.hosts.forEach { host in
          guard let hostname = host.host.hostname.data(using: .utf8) else {
            logger.warning("failed to encode hostname into UTF8 data")
            return
          }
          ctrl.send(bytes: hostname, to: host)
        }
        return InputMode.Input()
      }
      
      // connection string
      else if "c" ~= input {
        ctrl.hosts.forEach { host in
          guard let hostname = host.host.connectionString.data(using: .utf8) else {
            logger.warning("failed to encode hostname into UTF8 data")
            return
          }
          ctrl.send(bytes: hostname, to: host)
        }
        return InputMode.Input()
      }
      
      // Window ID
      else if "i" ~= input {
        ctrl.hosts.forEach { host in
          guard let wid = String(host.tab.windowId).data(using: .utf8) else {
            logger.warning("failed to encode window ID into UTF8 data")
            return
          }
          ctrl.send(bytes: wid, to: host)
        }
        return InputMode.Input()
      }
      
      else if 0x1b ~= input {
        // escape (\e)
        
        if input.dropEscapeSequence() {
          // if is escape sequence -> delete it and beep.
          beep()
          return nil
        } else {
          // else switch to input mode
          return InputMode.Input()
        }
      } else {
        input.removeAll()
        beep()
      }
      return nil
    }
  }
}

// MARK: -
extension InputMode {
  
  struct Sort: InputModeProtocol {
    
    var id: String { "sort" }
    
    var raw: Bool { true }
    
    func prompt(_ ctrl: Controller) -> String {
      "Choose sort order: (Esc to exit)\r\n" +
      "[h]ostname, window [i]d"
    }
    
    func onEnable(_ ctrl: Controller) throws {
      
    }
    
    func parse(input: inout [UInt8], _ ctrl: Controller) throws -> (any InputModeProtocol)? {
      // hostname
      if "h" ~= input {
        ctrl.hosts.sort { h1, h2 in
          // sort by hostname, port, username
          (h1.host.hostname, h1.host.port ?? 0, h1.host.user ?? "") < (h2.host.hostname, h2.host.port ?? 0, h2.host.user ?? "")
        }
        ctrl.layout()
        return InputMode.Input()
      }
      
      // Window ID (should match original order as window ID are increasing)
      else if "i" ~= input {
        ctrl.hosts.sort { h1, h2 in
          h1.tab.windowId < h2.tab.windowId
        }
        ctrl.layout()
        return InputMode.Input()
      }
      
      else if 0x1b ~= input {
        // escape (\e)
        
        if input.dropEscapeSequence() {
          // if is escape sequence -> delete it and beep.
          beep()
          return nil
        } else {
          // else switch to input mode
          return InputMode.Input()
        }
      } else {
        input.removeAll()
        beep()
      }
      return nil
    }
  }
}

// MARK: -
extension InputMode {

  struct AddHost: InputModeProtocol {

    var id: String { "add-host" }

    var raw: Bool { false }

    func prompt(_ ctrl: Controller) -> String {
      "Add Host: "
    }

    func onEnable(_ ctrl: Controller) throws {

    }

    func parse(input: inout [UInt8], _ ctrl: Controller) throws -> (any InputModeProtocol)? {
      // If data contains an escape char -> discard all data
      // This is different from original csshx which only discard data up to the escape char.
      if input.contains(27) {
        input.removeAll()
        return InputMode.Input()
      }
      guard let hostname = String(bytes: input, encoding: .utf8) else {
        input.removeAll()
        beep()
        return nil
      }
      // Whatever append -> discard buffer content
      input.removeAll()

      let (user, host, p) = try hostname.trimmingCharacters(in: .whitespacesAndNewlines).parseUserHostPort()
      let target = Target(user: user, hostname: host, port: p.flatMap(UInt16.init), command: nil)
      try ctrl.add(host: target) { error in
        if let error {
          logger.warning("error while starting host \(target.connectionString, privacy: .public): \(error, privacy: .public)")
        } else {
          ctrl.layout()
        }
      }
      return InputMode.Input()
    }
  }
}

// MARK: - Window Layout Management

// TODO: multi screen support -> add an keystroke to move to the next screen (maybe tab).
// TODO: Add the screen ID in the prompt ?

private extension Comparable {
  func clamp(to range: Range<Self>) -> Self {
    return Swift.max(range.lowerBound, Swift.min(range.upperBound, self))
  }
}

private extension Controller {
  var controllerScreen: Screen? { windowManager.controllerScreen }

  func move(screen: Screen, dx: Int, dy: Int) {
    if var frame = tab?.window.frame {
      let xRange = screen.visibleFrame.minX..<(screen.visibleFrame.maxX - frame.width)
      frame.origin.x = (frame.origin.x + 10 * CGFloat(dx)).clamp(to: xRange)

      let yRange = screen.visibleFrame.minY..<(screen.visibleFrame.maxY - frame.height)
      frame.origin.y = (frame.origin.y + 10 * CGFloat(dy)).clamp(to: yRange)

      tab?.window.origin = frame.origin
    }
  }

  func resize(screen: Screen, dx: Int, dy: Int) {
    if var frame = tab?.window.frame {
      let xRange = 40..<(screen.visibleFrame.maxX - frame.minX)
      frame.size.width = (frame.size.width + 10 * CGFloat(dx)).clamp(to: xRange)

      let yRange = 40..<(screen.visibleFrame.maxY - frame.minY)
      frame.size.height = (frame.size.height + 10 * CGFloat(dy)).clamp(to: yRange)

      tab?.window.frame = frame
    }
  }
}

// MARK: -
extension InputMode {

  struct Enable: InputModeProtocol {

    var id: String { "enable" }

    var raw: Bool { true }

    private var screen: Screen? = nil

    var selection: HostWindow? = nil {
      didSet {
        oldValue?.selected = false
        selection?.selected = true
      }
    }

    func prompt(_ ctrl: Controller) -> String {
      "Select window with Arrow keys or i,j,k,l: (Esc to exit)\r\n" +
      "[e]nable input, [d]isable input, disable [o]thers, disable [O]thers and zoom, [t]oggle input\r\n"
    }

    mutating func onEnable(_ ctrl: Controller) throws {
      ctrl.hosts.forEach { $0.tab.window.zoomed = false }
      // select first host window
      selection = ctrl.hosts.first

      // default to controller screen
      screen = ctrl.controllerScreen
    }

    mutating func parse(input: inout [UInt8], _ ctrl: Controller) throws -> (any InputModeProtocol)? {
      // ↑
      if "i" ~= input || "\u{1b}[A" ~= input {
        if let selected = selection,
           let next = screen?.getHostAbove(selected.id).flatMap({ hid in
             ctrl.hosts.first { $0.id == hid }
           }) {
          selection = next
        }
      }
      // ↓
      else if "k" ~= input || "\u{1b}[B" ~= input {
        if let selected = selection,
           let next = screen?.getHostBelow(selected.id).flatMap({ hid in
             ctrl.hosts.first { $0.id == hid }
           }) {
          selection = next
        }
      }
      // →
      else if "l" ~= input || "\u{1b}[C" ~= input {
        if let selected = selection,
           let next = screen?.getHostRight(of: selected.id).flatMap({ hid in
             ctrl.hosts.first { $0.id == hid }
           }) {
          selection = next
        }
      }
      // ←
      else if "j" ~= input || "\u{1b}[D" ~= input {
        if let selected = selection,
           let next = screen?.getHostLeft(of: selected.id).flatMap({ hid in
             ctrl.hosts.first { $0.id == hid }
           }) {
          selection = next
        }
      }

      else if "e" ~= input {
        selection?.enabled = true
      }

      else if "d" ~= input {
        selection?.enabled = false
      }

      else if "t" ~= input {
        if let selected = selection {
          selected.enabled = !selected.enabled
        }
      }

      // disable others
      else if "o" ~= input {
        if let selected = selection {
          ctrl.hosts.forEach {
            if ($0 != selected) {
              $0.enabled = false
            }
            $0.selected = false
          }
          selected.enabled = true
          return InputMode.Input()
        }
      }

      // disable others and zoom
      else if "O" ~= input {
        if let selected = selection {
          ctrl.hosts.forEach {
            if ($0 != selected) {
              $0.enabled = false
            }
            $0.selected = false
          }
          // zoom
          if let frame = screen?.hostsFrame {
            selected.tab.window.frame = frame
          }
          selected.enabled = true
          // bring it front
          selected.tab.window.frontmost = true
          // but still behind controller window
          ctrl.tab?.window.frontmost = true
          return InputMode.Input()
        }
      }


      else if 0x1b ~= input || 0x0d ~= input {
        // escape (\e)

        // Should always returns false for 0x0d
        if input.dropEscapeSequence() {
          // if is escape sequence -> delete it and beep.
          beep()
          return nil
        } else {
          // else switch to input mode
          ctrl.hosts.forEach { $0.selected = false }
          return InputMode.Input()
        }
      } else {
        input.removeAll()
        beep()
      }

      return nil
    }
  }
}

// MARK: -
extension InputMode {

  struct Bounds: InputModeProtocol {

    var id: String { "bounds" }

    var raw: Bool { true }

    private var screen: Screen? = nil

    func prompt(_ ctrl: Controller) -> String {
      "Move and resize master with mouse to define bounds: (Enter to accept, Esc to cancel)\r\n" +
      "(Also Arrow keys of i,j,k,l can move window, hold Shift to resize)\r\n" +
      "[r]eset to default, [f]ull screen, [p]rint screens configuration"
    }

    mutating func onEnable(_ ctrl: Controller) throws {
      // hide all host windows
      ctrl.hosts.forEach { $0.tab.hide() }

      // switch master to resizing mode (color, …)
      if let color = ctrl.settings.resizingTextColor {
        ctrl.tab?.setTextColor(color: color)
      }
      if let color = ctrl.settings.resizingBackgroundColor {
        ctrl.tab?.setBackgroundColor(color: color)
      }

      // resize master to match "layout manager" bounds
      screen = ctrl.controllerScreen
      if let screen, !screen.frame.isEmpty {
        ctrl.tab?.window.frame = screen.frame
      }
    }

    mutating func parse(input: inout [UInt8], _ ctrl: Controller) throws -> (any InputModeProtocol)? {
      guard let screen = screen else {
        // TODO: exit bounds mode ?
        return nil
      }

      // ↑
      if "i" ~= input || "\u{1b}[A" ~= input {
        ctrl.move(screen: screen, dx: 0, dy: 1)
      }
      // shift ↑
      else if "I" ~= input || "\u{1b}[1;2A" ~= input {
        ctrl.resize(screen: screen, dx: 0, dy: 1)
      }

      // ↓
      else if "k" ~= input || "\u{1b}[B" ~= input {
        ctrl.move(screen: screen, dx: 0, dy: -1)
      }
      // shift ↓
      else if "K" ~= input || "\u{1b}[1;2B" ~= input {
        ctrl.resize(screen: screen, dx: 0, dy: -1)
      }

      // →
      else if "l" ~= input || "\u{1b}[C" ~= input {
        ctrl.move(screen: screen, dx: 1, dy: 0)
      }
      // shift →
      else if "L" ~= input || "\u{1b}[1;2C" ~= input {
        ctrl.resize(screen: screen, dx: 1, dy: 0)
      }

      // ←
      else if "j" ~= input || "\u{1b}[D" ~= input {
        ctrl.move(screen: screen, dx: -1, dy: 0)
      }
      // shift ←
      else if "J" ~= input || "\u{1b}[1;2D" ~= input {
        ctrl.resize(screen: screen, dx: -1, dy: 0)
      }

      // print screens configuration
      else if "p" ~= input {
        // FIXME: update to match multi-screen config once defined.
        if let bounds = ctrl.tab?.window.frame {
          fwrite(str: "\r\n\r\nscreen_bounds = { \(Int(bounds.origin.x)), \(Int(bounds.origin.y)), \(Int(bounds.width)), \(Int(bounds.height)) }\r\n", file: stdout)
        } else {
          beep()
        }
      }

      // full screen
      else if "f" ~= input {
        if !screen.visibleFrame.isEmpty {
          ctrl.tab?.window.frame = screen.visibleFrame
        }
      }

      // apply
      else if "\r" ~= input {
        if let frame = ctrl.tab?.frame {
          screen.set(frame: frame, isRelative: false)
        }
        ctrl.setControllerColors()
        ctrl.layout()
        return InputMode.Input()
      }

      else if 0x1b ~= input {
        // escape (\e)

        if input.dropEscapeSequence() {
          // if is escape sequence -> delete it and beep.
          beep()
          return nil
        } else {
          // else switch to input mode
          ctrl.setControllerColors()
          ctrl.layout()
          return InputMode.Input()
        }
      } else {
        input.removeAll()
        beep()
      }
      return nil
    }
  }
}

// MARK: -
// grid mode:
// use arrows to increase/decrease count of rows/columns of the current screen.
// TODO: multiscreen support
// allows setting the rows/columns count to 0 if there is multiple screens -> disable/enable the screen accordingly.
// use tab to circle over all screens.
extension InputMode {
  
  struct Grid: InputModeProtocol {
    
    var id: String { "grid" }
    
    var raw: Bool { true }
    
    private var screen: Screen? = nil
    
    func prompt(_ ctrl: Controller) -> String {
      "Change the rows/columns layout with Arrow keys or i,j,k,l: (Esc to exit)\r\n" +
      "[r]eset layout, [p]rint screens configuration\r\n"
    }
    
    mutating func onEnable(_ ctrl: Controller) throws {
      // default to controller screen
      screen = ctrl.controllerScreen
    }
    
    mutating func parse(input: inout [UInt8], _ ctrl: Controller) throws -> (any InputModeProtocol)? {
      // ↑
      if "i" ~= input || "\u{1b}[A" ~= input {
        guard let screen, screen.rows < screen.hostCount else {
          beep()
          return nil
        }
        screen.set(rows: screen.rows + 1)
        ctrl.layout()
      }
      // ↓
      else if "k" ~= input || "\u{1b}[B" ~= input {
        guard let screen, screen.rows > 1 else {
          beep()
          return nil
        }
        screen.set(rows: screen.rows - 1)
        ctrl.layout()
      }
      // →
      else if "l" ~= input || "\u{1b}[C" ~= input {
        guard let screen, screen.columns < screen.hostCount else {
          beep()
          return nil
        }
        screen.set(columns: screen.columns + 1)
        ctrl.layout()
      }
      // ←
      else if "j" ~= input || "\u{1b}[D" ~= input {
        guard let screen, screen.columns > 1 else {
          beep()
          return nil
        }
        screen.set(columns: screen.columns - 1)
        ctrl.layout()
      }
      
      // reset layout
      else if "r" ~= input {
        screen?.set(columns: 0)
        ctrl.layout()
      }
      
      else if 0x1b ~= input {
        // escape (\e)
        
        if input.dropEscapeSequence() {
          // if is escape sequence -> delete it and beep.
          beep()
          return nil
        } else {
          // else switch to input mode
          return InputMode.Input()
        }
      } else {
        input.removeAll()
        beep()
      }
      
      return nil
    }
  }
}
