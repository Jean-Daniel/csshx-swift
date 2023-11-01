//
//  WindowLayoutManager.swift
//  csshx
//
//  Created by Jean-Daniel Dupas on 23/10/2023.
//

import Foundation
import AppKit

struct ScreenId {
  let rawValue: Int
}

// TODO: Listen for screen configuration change notification
struct WindowLayoutManager {

  struct Config {
    var rows: Int = 0
    var columns: Int = 0
    var screens: Array<Int> = []
    var screenBounds: CGRect? = nil
    var controllerHeight: CGFloat = 87 // Pixels ?
  }

  struct Screen {
    let id: ScreenId
    var bounds: CGRect
    var isControllerScreen = false

    // Layout state
    var hosts: [HostWindow.ID] = []
    private(set) var rows: Int = 0
    private(set) var columns: Int = 0

    fileprivate mutating func set(hosts: [HostWindow.ID], rows: Int, columns: Int) {
      self.hosts = hosts
      self.rows = rows
      self.columns = columns
    }

    func getHostAbove(_ host: HostWindow.ID) -> HostWindow.ID? {
      guard columns > 0,
            let idx = hosts.firstIndex(of: host) else {
        return nil
      }
      let row = idx / columns
      // This is not the first row -> return host above
      if row > 0 {
        return hosts[idx - columns]
      }

      // Lookup the last row containing a value in column
      let column = idx % columns
      // Compute index of the host above
      let wrapIdx = (rows - 1) * columns + column
      if wrapIdx >= hosts.endIndex {
        return (wrapIdx - columns) != idx ? hosts[wrapIdx - columns] : nil
      }
      return hosts[wrapIdx]
    }

    func getHostBelow(_ host: HostWindow.ID) -> HostWindow.ID? {
      guard columns > 0,
            let idx = hosts.firstIndex(of: host) else {
        return nil
      }
      let row = idx / columns
      // Lookup the last row containing a value in column
      let column = idx % columns

      // Compute index of the previous host
      let belowIdx = (row + 1) * columns + column
      if belowIdx >= hosts.endIndex {
        return (column != idx) ? hosts[column] : nil
      }
      return hosts[belowIdx]
    }

    func getHostAfter(_ host: HostWindow.ID) -> HostWindow.ID? {
      guard columns > 0,
            let idx = hosts.firstIndex(of: host) else {
        return nil
      }
      let column = idx % columns
      // wrap around when reaching end of row
      if column == columns - 1 || idx == hosts.endIndex - 1 {
        return column > 0 ? hosts[idx - column] : nil
      }
      return hosts[idx + 1]
    }

    func getHostBefore(_ host: HostWindow.ID) -> HostWindow.ID? {
      guard columns > 0,
            let idx = hosts.firstIndex(of: host) else {
        return nil
      }
      let column = idx % columns
      // wrap around when reaching start of row
      if column == 0 {
        let wrapIdx = min(idx + columns - 1, hosts.endIndex - 1)
        return (wrapIdx != idx) ? hosts[wrapIdx] : nil
      }
      return hosts[idx - 1]
    }

    private func getRow(_ host: HostWindow.ID) -> Int? {
      guard columns > 0,
            let idx = hosts.firstIndex(of: host) else {
        return nil
      }
      return idx / columns
    }

    private func getColumn(_ host: HostWindow.ID) -> Int? {
      guard columns > 0,
            let idx = hosts.firstIndex(of: host) else {
        return nil
      }
      return idx % columns
    }
  }

  private var config: Config

  private var screens: [Screen]

  private var defaultWindowRatio: Double = 0

  init(config: Config) {
    self.config = config
    // TODO: validate that user requested bounds is compatible with the screen bounds

    screens = (try? Self.visibleFrames(screens: config.screens)) ?? []

    // TODO: let the user specify controller screen, or try to infer it from controller window
    if !screens.isEmpty {
      screens[0].isControllerScreen = true
    }
  }

  func rows(for screen: Int32) -> Int { return 0 }
  func set(rows: Int, for screen: Int32) {}

  func columns(for screen: Int32) -> Int { return 0 }
  func set(columns: Int, for screen: Int32) {}

  private func screen(for host: HostWindow.ID) -> Screen? {
    return screens.first { $0.hosts.contains(host) }
  }

  func getHostAbove(_ host: HostWindow.ID) -> HostWindow.ID? {
    return screen(for: host)?.getHostAbove(host)
  }

  func getHostBelow(_ host: HostWindow.ID) -> HostWindow.ID? {
    return screen(for: host)?.getHostBelow(host)
  }

  func getHostAfter(_ host: HostWindow.ID) -> HostWindow.ID? {
    return screen(for: host)?.getHostAfter(host)
  }

  func getHostBefore(_ host: HostWindow.ID) -> HostWindow.ID? {
    return screen(for: host)?.getHostBefore(host)
  }

  mutating func setDefaultWindowRatio(from tab: Terminal.Tab) {
    if (defaultWindowRatio <= 0) {
      let bounds = tab.frame()
      if (!bounds.isEmpty) {
        defaultWindowRatio =  bounds.width / bounds.height
      }
    }
  }

  mutating func layout(controller tab: Terminal.Tab, hosts: [HostWindow]) {
    guard !screens.isEmpty else {
      logger.warning("failed to compute screen bounds. Skipping layout pass.")
      return
    }

    tab.window.miniaturized = false

    // FIXME: find on which screen the controller currently is.
    tab.window.frame = CGRect(origin: screens[0].bounds.origin,
                              size: CGSize(width: screens[0].bounds.width, height: config.controllerHeight))

    // TODO: check set resulting frame ?
    guard !hosts.isEmpty else { return }

    layout(hosts: hosts, space: tab.space)
  }

  private mutating func layout(hosts: [HostWindow], space: Int32) {
    assert(!hosts.isEmpty)
    assert(!screens.isEmpty)

    // TODO: create and save grid for selection handling.

    var hostsByScreen: [[HostWindow]] = []
    // TODO: compute surface of each screen and split host windows proportionally.
    let base = hosts.count / screens.count
    let remainder = hosts.count % screens.count

    var cursor = 0
    for _ in 0..<remainder {
      hostsByScreen.append(Array(hosts[cursor...(cursor + base)]))
      cursor += base + 1
    }
    for _ in remainder..<screens.count {
      hostsByScreen.append(Array(hosts[cursor..<(cursor + base)]))
      cursor += base
    }

    var first = true
    for (idx, hosts) in hostsByScreen.enumerated() {
      let (rows, columns) = getGrid(for: getHostsBounds(for: screens[idx]), hosts: hosts.count)
      screens[idx].set(hosts: hosts.map { $0.id }, rows: rows, columns: columns)

      if (first) {
        // If main screen -> remove controller frame
        layout(hosts: hosts, on: screens[idx], space: space)
        first = false
      } else {
        layout(hosts: hosts, on: screens[idx], space: space)
      }
    }
  }

  private func getHostsBounds(for screen: Screen) -> CGRect {
    if (screen.isControllerScreen) {
      // Remove space reserved for controller window from controller screen bounds
      let (_, bounds) = screen.bounds.divided(atDistance: config.controllerHeight, from: .minYEdge)
      return bounds
    } else {
      return screen.bounds
    }
  }

  private mutating func getGrid(for bounds: CGRect, hosts count: Int) -> (Int, Int) {
    if config.rows > 0 {
      let rows = min(config.rows, count)
      let columns = Int(ceil(Float(count) / Float(rows)))
      return (rows, columns)
    } else if config.columns > 0 {
      let columns = min(config.columns, count)
      let rows = Int(ceil(Float(count) / Float(columns)))
      return (rows, columns)
    } else if (defaultWindowRatio > 0) {
      return getBestLayout(for: defaultWindowRatio, hosts: count, on: bounds)
    }
    return (0, 0)
  }

  // Compute number of rows
  private mutating func layout(hosts: [HostWindow], on screen: Screen, space: Int32) {
    guard screen.rows > 0, screen.columns > 0 else { return }

    let bounds = getHostsBounds(for: screen)
    let width = bounds.width / CGFloat(screen.columns)
    let height = bounds.height / CGFloat(screen.rows)

    for (idx, host) in hosts.enumerated() {
      let x = CGFloat(idx % screen.columns) * width
      let y = CGFloat(idx / screen.columns) * height

      let tab = host.tab
      // Move to controller space if needed
      if space > 0 {
        tab.space = space
      }
      tab.window.zoomed = false
      tab.window.visible = true
      tab.window.miniaturized = false
      tab.window.frontmost = true
      // Layout from top to bottom
      tab.window.frame = CGRect(x: bounds.minX + x, y: bounds.maxY - height - y, width: width, height: height)
    }
  }

  private static func visibleFrames(screens: Array<Int>) throws -> [Screen] {
    // Default to main screen (screen with the active window)
    if (screens.isEmpty) {
      guard let screen = NSScreen.main else {
        throw POSIXError(.ENODEV)
      }
      return [Screen(id: ScreenId(rawValue: 0), bounds: screen.visibleFrame)]
    }

    let displays = NSScreen.screens
    guard !displays.isEmpty else {
      throw POSIXError(.ENODEV)
    }

    var used = Set<Int>()
    var frames = [Screen]()
    for idx in screens {
      guard (1...displays.count).contains(idx) else {
        logger.warning("screen number must be in range [1;\(displays.count)]")
        continue
      }
      guard !used.contains(idx - 1) else {
        continue
      }
      used.insert(idx - 1)
      frames.append(Screen(id: ScreenId(rawValue: idx - 1), bounds: displays[idx - 1].visibleFrame))
    }

    guard !frames.isEmpty else {
      // default to main screen (with fallback to primary screen)
      return [Screen(id: ScreenId(rawValue: 0), bounds: (NSScreen.main ?? displays[0]).visibleFrame)]
    }

    // TODO: sort screen from left to right ?
    return frames
  }
}


