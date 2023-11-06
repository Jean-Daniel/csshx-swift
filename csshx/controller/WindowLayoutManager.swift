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

// Maintains a list of all screens, with current configuration (columns, bounds, …)
// On layout:
//  - dispatch hosts on active screens (default to all).
//  - layout each screen using current screen configuration.
// On screen removed -> auto relayout
// On screen plugged ->
//    - if known screen: auto relayout
//    - if new screen: wait for relayout command.

// TODO: Listen for screen configuration change notification
struct WindowLayoutManager {

  struct Config {
//    var rows: Int = 0
//    var columns: Int = 0
//    var screens: Array<Int> = []
//    var screenBounds: CGRect? = nil
    var controllerHeight: CGFloat = 87 // Pixels ?
  }

  private var config: Config

  private var screens: [Screen]
  private(set) var controllerScreen: Screen? = nil

  private var defaultWindowRatio: Double = 0

  init(config: Config) {
    self.config = config

    screens = NSScreen.screens.compactMap({ screen in
      guard let uuid = screen._UUIDString() else { return nil }
      return Screen(uuid: uuid, visibleFrame: screen.visibleFrame)
    })
  }

  func rows(for screen: Int32) -> Int { return 0 }
  func set(rows: Int, for screen: Int32) {}

  func columns(for screen: Int32) -> Int { return 0 }
  func set(columns: Int, for screen: Int32) {}

  private func screen(for frame: CGRect) -> Screen? {
    var best: Screen? = nil
    var bestScore: CGFloat = 0
    for screen in screens {
      let rect = screen.visibleFrame.intersection(frame)
      guard !rect.isEmpty else { continue }
      let score = rect.width * rect.height
      if score > bestScore {
        bestScore = score
        best = screen
      }
    }
    return best ?? screens.first(where: \.plugged)
  }

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
      let bounds = tab.frame
      if (!bounds.isEmpty) {
        defaultWindowRatio =  bounds.width / bounds.height
      }
    }
  }

  mutating func layout(controller tab: Terminal.Tab, hosts: [HostWindow]) {
    // TODO: refresh active screens based on configuration
    screens.forEach { $0.active = $0.plugged }

    guard screens.contains(where: { $0.plugged && $0.active }) else {
      logger.warning("failed to compute screen bounds. Skipping layout pass.")
      return
    }

    tab.window.miniaturized = false

    // find on which screen the controller currently is.
    if let screen = screen(for: tab.window.frame) {
      controllerScreen = screen
      screen.updateFrame(reserved: config.controllerHeight)
      tab.window.frame = CGRect(origin: screen.frame.origin,
                                size: CGSize(width: screen.frame.width, height: config.controllerHeight))
      // TODO: check resulting frame to make sure controllerHeight is respected.
    }

    guard !hosts.isEmpty else { return }
    layout(hosts: hosts, space: tab.space)
  }

  private mutating func layout(hosts: [HostWindow], space: Int32) {
    assert(!hosts.isEmpty)
    let screens = screens.filter { $0.plugged && $0.active }
    guard !screens.isEmpty else { return }

    // Update all screens frames before computing windows layouts
    screens.forEach { if ($0.uuid != controllerScreen?.uuid) { $0.updateFrame(reserved: 0) } }

    // compute surface of each screen and split host windows proportionally.
    var totalArea = screens.reduce(0.0) { area, screen in
      return area + screen.area
    }

    var dispatched = 0
    for screen in screens {
      if dispatched < hosts.count {
        // Compute count of hosts proportionally to the screen area.
        let count = Int(ceil(CGFloat(hosts.count - dispatched) * (screen.area / totalArea)))
        // Compute screen frame and grid layout
        screen.set(hosts: hosts[dispatched..<(dispatched + count)].map(\.id),
                   ratio: defaultWindowRatio)

        totalArea -= screen.area
        dispatched += count
        assert(dispatched <= hosts.count)
      } else {
        // Clear screen
        screen.set(hosts: [], ratio: 1)
        // disable the screen
        screen.active = false
      }
    }

    var hostsById = [HostWindow.ID:HostWindow]()
    hosts.forEach { host in hostsById[host.id] = host }
    for screen in screens {
      layout(screen: screen, space: space, hosts: hostsById)
    }
  }

  private mutating func layout(screen: Screen, space: Int32, hosts: [HostWindow.ID:HostWindow]) {
    guard screen.rows > 0, screen.columns > 0 else { return }

    let bounds = screen.hostsFrame
    let width = bounds.width / CGFloat(screen.columns)
    let height = bounds.height / CGFloat(screen.rows)

    for (idx, hostId) in screen.hosts.enumerated() {
      guard let host = hosts[hostId] else { return }

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

//  private static func visibleFrames(screens: Array<Int>) throws -> [Screen] {
//    // Default to all screens
//    if (screens.isEmpty) {
//      return NSScreen.screens.enumerated().map({ idx, screen in
//        Screen(id: ScreenId(rawValue: idx), bounds: screen.visibleFrame, maxBounds: screen.visibleFrame)
//      })
//    }
//
//    let displays = NSScreen.screens
//    guard !displays.isEmpty else {
//      throw POSIXError(.ENODEV)
//    }
//
//    var used = Set<Int>()
//    var frames = [Screen]()
//    for idx in screens {
//      guard (1...displays.count).contains(idx) else {
//        logger.warning("screen number must be in range [1;\(displays.count)]")
//        continue
//      }
//      guard !used.contains(idx - 1) else {
//        continue
//      }
//      used.insert(idx - 1)
//      frames.append(Screen(id: ScreenId(rawValue: idx - 1), bounds: displays[idx - 1].visibleFrame, maxBounds: displays[idx - 1].visibleFrame))
//    }
//
//    guard !frames.isEmpty else {
//      // default to main screen (with fallback to primary screen)
//      let bounds = (NSScreen.main ?? displays[0]).visibleFrame
//      return [Screen(id: ScreenId(rawValue: 0), bounds: bounds, maxBounds: bounds)]
//    }
//
//    // TODO: sort screen from left to right ?
//    return frames
//  }
}

class Screen {
  let uuid: String // screen UUID.
  // Actual screen visible frame (fullscreen frame)
  var visibleFrame: CGRect

  fileprivate var plugged: Bool = true
  fileprivate var active: Bool = false

  // Configuration
  var requestedRows: Int = 0
  var requestedColumns: Int = 0
  private(set) var requestedFrame: CGRect? // relative to screen frame

  // Computed layout
  var frame: CGRect = CGRect.zero
  fileprivate var reserved: CGFloat = 0

  fileprivate var hostsFrame: CGRect {
    if (reserved > 0) {
      // Remove space reserved for controller window from screen frame
      let (_, bounds) = frame.divided(atDistance: reserved, from: .minYEdge)
      return bounds
    } else {
      return frame
    }
  }

  fileprivate var hosts: [HostWindow.ID] = []

  fileprivate var rows: Int = 0
  fileprivate var columns: Int = 0

  fileprivate init(uuid: String, visibleFrame frame: CGRect) {
    self.uuid = uuid
    self.visibleFrame = frame
  }

  func setRequestFrame(_ frame: CGRect, isRelative: Bool) {
    if (isRelative) {
      requestedFrame = frame
    } else {
      let screen = visibleFrame
      requestedFrame = frame.offsetBy(dx: -screen.origin.x, dy: -screen.origin.y)
    }
  }

  // Layout pass
  fileprivate func updateFrame(reserved: CGFloat) {
    if let requested = requestedFrame {
      frame = requested.offsetBy(dx: visibleFrame.origin.x, dy: visibleFrame.origin.y)
      // Clip to visible frame
      frame = frame.intersection(visibleFrame)
    } else {
      frame = visibleFrame
    }

    self.reserved = reserved
  }

  fileprivate func set(hosts: [HostWindow.ID], ratio: CGFloat) {
    self.hosts = hosts

    // Update Grid
    if (!hosts.isEmpty) {
      updateGrid(for: ratio)
    } else {
      rows = 0
      columns = 0
    }
  }

  private func updateGrid(for ratio: CGFloat) {
    let count = hosts.count
    if requestedRows > 0 {
      rows = min(requestedRows, count)
      columns = Int(ceil(Float(count) / Float(rows)))
    } else if requestedColumns > 0 {
      columns = min(requestedColumns, count)
      rows = Int(ceil(Float(count) / Float(columns)))
    } else if (ratio > 0) {
      (rows, columns) = getBestLayout(for: ratio, hosts: count, on: frame.size)
    } else {
      rows = 0
      columns = 0
    }
  }

  fileprivate var area: CGFloat { frame.width * frame.height }

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

//  private func getRow(_ host: HostWindow.ID) -> Int? {
//    guard columns > 0,
//          let idx = hosts.firstIndex(of: host) else {
//      return nil
//    }
//    return idx / columns
//  }
//
//  private func getColumn(_ host: HostWindow.ID) -> Int? {
//    guard columns > 0,
//          let idx = hosts.firstIndex(of: host) else {
//      return nil
//    }
//    return idx % columns
//  }
}



