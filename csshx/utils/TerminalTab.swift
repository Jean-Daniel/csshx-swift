//
//  Window.swift
//  csshx
//
//  Created by Jean-Daniel Dupas on 10/10/2023.
//

import Foundation
import RegexBuilder

struct ScriptingBridgeError: Error {

}

private let _unsafe = Regex {
  CharacterClass(
    .anyOf("@%+=:,./-"),
    .word
  )
  .inverted
}

/// Return a shell-escaped version of the string
private func quote(arg: String) -> String {
  guard !arg.isEmpty else { return "''" }

  if arg.firstMatch(of: _unsafe) == nil {
    return arg
  }

  // use single quotes, and put single quotes into double quotes
  // the string $'b is then quoted as '$'"'"'b'
  return "'" + arg.replacing("'", with: #"'"'"'"#) + "'"
}

extension Terminal {

  // MARK: Color
  struct Color: Sendable {
    let red: CGFloat
    let green: CGFloat
    let blue: CGFloat

    init(red: CGFloat, green: CGFloat, blue: CGFloat) {
      self.red = red
      self.green = green
      self.blue = blue
    }

    fileprivate func asNSColor() -> NSColor {
      return NSColor(srgbRed: red, green: green, blue: blue, alpha: 1)
    }
  }

  struct Tab: Equatable {

    let tab: TerminalTab
    let window: TerminalWindow
    let terminal: TerminalApplication

    let tabIdx: Int
    let windowId: CGWindowID

    static func == (lhs: Tab, rhs: Tab) -> Bool {
      return lhs.windowId == rhs.windowId && lhs.tabIdx == rhs.tabIdx 
    }

    func run(args: [String], clear: Bool, exec: Bool) throws {
      let shell = Terminal.shell

      // Hide the command from any shell history
      var script = ""
      switch (shell) {
        case "bash", "sh":
          script.append("history -d $(($HISTCMD-1)) && ")
          // TODO: - (t)csh, ksh, zsh
        default:
          // prepend space to ignore history in fish and zsh if configured
          script.append(" ")
          break
      }

      if clear { script.append("clear && ") }
      if exec { script.append("exec ") }

      script += args.map(quote(arg:)).joined(separator: " ")
      guard terminal.doScript(script, in: tab) == tab else {
        throw ScriptingBridgeError()
      }
    }

    var tty: dev_t {
      return tab.ttydev()
    }
    
    // MARK: Window Management
    var frame: CGRect {
      return window.frame
    }

    func move(x dx: CGFloat, y dy: CGFloat) {
      let orig = window.origin
      window.origin = NSPoint(x: orig.x + 5 * dx, y: orig.y + 5 * dy)
    }

    func grow(width dw: CGFloat, height dh: CGFloat) {
      let size = window.size
      window.size = CGPoint(x: size.x + 5 * dw, y: size.y + 5 * dh)
    }

    func hide() {
      window.visible = false
    }

    func miniaturize() {
      window.miniaturized = true
    }

    func close() {
      window.closeSaving(TerminalSaveOptionsNo, savingIn: nil)
    }

    var space: Int32 {
      get {
//        var ws: CGSWorkspace = -1
//        let error: CGError = CGSGetWindowWorkspace(CGSDefaultConnection(), windowId, &ws)
//        guard error == .success else {
//          logger.warning("error while querying window space: \(error.rawValue)")
//          return -1
//        }
        return 0
      }
      nonmutating set {
//        var wids = windowId
//        let error = CGSMoveWorkspaceWindowList(CGSDefaultConnection(), &wids, 1, CGSWorkspace(newValue))
//        if error != .success {
//          logger.warning("error while setting window space: \(error.rawValue)")
//        }
      }
    }

    func setProfile(_ profile: String) -> Bool {
      guard let settings = terminal.settingsSets().object(withName: profile) as? TerminalSettingsSet else {
        // should never fails as it only create an ObjectDescriptor
        logger.warning("failed to create settings set \(profile)")
        return false
      }
      tab.currentSettings = settings
      return tab.currentSettings.name == profile
    }

    /// Terminal does not support alpha channel when passing colors. When resetting a color to the default value,
    /// instead of fetching the color from the profile and setting it, set the color using an object specifier pointing to the
    /// tab's "settings set" original value.
    func setTextColor(color: Color?) {
      if let c = color?.asNSColor() {
        tab.currentSettings.normalTextColor = c
      } else {
        try? reset(property: pTextColor)
      }
    }

    func setBackgroundColor(color: Color?) {
      if let c = color?.asNSColor() {
        tab.currentSettings.backgroundColor = c
      } else {
        try? reset(property: pBackgroundColor)
      }
    }

    private func reset(property: AEKeyword) throws {
      // set <property> of current settings of the_tab to <property> of settings set (name of current settings of the_tab)
      guard let settings = tab.currentSettings,
      let name = settings.name else {
        throw ScriptingBridgeError()
      }

      let defaults = terminal.settingsSets().object(withName: name) as! SBObject
      let src = defaults.property(withCode: property)

      settings.property(withCode: property).setTo(src)
    }
  }
}

private class TerminalApplicationDelegate: SBApplicationDelegate {
  func eventDidFail(_ event: UnsafePointer<AppleEvent>, withError error: Error) -> Any? {
    let err = error as NSError
    logger.warning("apple event did failed with error: \(err)")
    return nil
  }
}

extension Terminal.Tab {

  init(tty: dev_t) throws {
    guard let bridge = TerminalApplication(bundleIdentifier: TerminalBundleId) else {
      throw ScriptingBridgeError()
    }
    bridge.delegate = TerminalApplicationDelegate()
    
    guard let tab = bridge.tab(withTTY: tty) else {
      throw ScriptingBridgeError()
    }

    try self.init(terminal: bridge, tab: tab)
  }

  init(window: CGWindowID, tab: Int) throws {
    guard let bridge = TerminalApplication(bundleIdentifier: TerminalBundleId) else {
      throw ScriptingBridgeError()
    }
    bridge.delegate = TerminalApplicationDelegate()

    guard let w = bridge.windows().object(withID: window) as? TerminalWindow,
          let t =  w.tabs().object(at: tab) as? TerminalTab else {
      throw ScriptingBridgeError()
    }
    self.init(tab: t, window: w, terminal: bridge, tabIdx: tab, windowId: window)
  }

  static func open() throws -> Self {
    guard let bridge = TerminalApplication(bundleIdentifier: TerminalBundleId) else {
      throw ScriptingBridgeError()
    }
    bridge.delegate = TerminalApplicationDelegate()

    guard let tab = bridge.doScript("", in: 0) else {
      throw ScriptingBridgeError()
    }

    return try Terminal.Tab.init(terminal: bridge, tab: tab);
  }

  private init(terminal: TerminalApplication, tab: TerminalTab) throws {

    // Get the window IDs from the Apple Event itself
    // The Tab Specifier looks like this:
    // 'obj '{
    //   'want':'ttab', 'form':'indx', 'seld':1, 'from':'obj '{
    //      'want':'cwin', 'form':'ID  ', 'seld':23600, 'from':[0x0,f0ef0e "Terminal"]
    //    }
    //  }
    // FIXME: check the 'form' of each specifier
    guard let specifier = tab.qualifiedSpecifier(),
          let tabIdx = specifier.forKeyword(kSeldProperty)?.int32Value,
          // Get the 'from' property which is a Window object specifier
          let windowSpec = specifier.forKeyword(kFromProperty),
          // Get the specifier key which is the window 'ID  '
          let windowId = windowSpec.forKeyword(kSeldProperty),
          // And finally, create a TabWindow representing the tab's window.
          let window = terminal.windows().object(withID: windowId.int32Value) as? TerminalWindow
    else {
      throw ScriptingBridgeError()
    }

    self.init(tab: tab,
              window: window,
              terminal: terminal,
              tabIdx: Int(tabIdx - 1), // convert to 0 based index, as it will be converted back by object(at:)
              windowId: CGWindowID(windowId.int32Value))
  }

}

extension TerminalTab {
  func ttydev() -> dev_t {
    guard let tty = tty else {
      return 0
    }
    var st = stat()
    guard stat(tty, &st) == 0 else { return 0 }
    return st.st_rdev
  }

  func index() throws -> Int {
    guard let specifier = qualifiedSpecifier(),
          let tabIdx = specifier.forKeyword(kSeldProperty)?.int32Value else {
      throw ScriptingBridgeError()
    }
    return Int(tabIdx)
  }
}
