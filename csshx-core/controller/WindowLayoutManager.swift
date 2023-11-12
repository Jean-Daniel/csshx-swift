//
//  WindowLayoutManager.swift
//  csshx
//
//  Created by Jean-Daniel Dupas.
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
// On active screen removed -> auto relayout
// On screen plugged ->
//    - if known screen: auto relayout
//    - if new screen: wait for relayout command.

class WindowLayoutManager {

  struct Config {
    var rows: Int = 0
    var columns: Int = 0
    // TODO: new configuration
    // - per screen bounds, and grid (rows, columns)
    // - controller screen
    var controllerHeight: CGFloat = 87 // Pixels ?
  }

  private var config: Config

  private var screens: [Screen]
  // array to keep unplug screens configuration
  private var unpluggedScreens = [String:Screen]()
  private(set) var controllerScreen: Screen? = nil

  // internal value use by smart layout
  private var defaultWindowRatio: Double = 0

  private var dirty: Bool = false
  static let displayReconfigurationCallback: CGDisplayReconfigurationCallBack = { displayId, flags, ctxt in
    // Skip begin configuration change events
    guard let ctxt, flags != .beginConfigurationFlag else { return }
    let value = Unmanaged<WindowLayoutManager>.fromOpaque(ctxt).takeUnretainedValue()
    value.didReconfigure(display: displayId, flags: flags)
  }

  init(config: Config) {
    self.config = config

    // Fetch initial screen configuration
    screens = NSScreen.screens.compactMap({ screen in
      guard let uuid = screen._UUIDString() else { return nil }
      let screen = Screen(uuid: uuid, visibleFrame: screen.visibleFrame)
      // Initialize default values from global config
      if config.rows > 0 {
        screen.set(rows: config.rows)
      }
      // Set column after to override rows if both set
      if config.columns > 0 {
        screen.set(columns: config.columns)
      }
      return screen
    })

    CGDisplayRegisterReconfigurationCallback(Self.displayReconfigurationCallback, Unmanaged.passUnretained(self).toOpaque())
  }

  deinit {
    CGDisplayRemoveReconfigurationCallback(Self.displayReconfigurationCallback, Unmanaged.passUnretained(self).toOpaque())
  }
  
  private func reloadScreens() {

  }

  private func didReconfigure(display: CGDirectDisplayID, flags: CGDisplayChangeSummaryFlags) {
    // FIXME: only handle desktop shape change events ?
    if (!dirty) {
      dirty = true
      DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(500)) {
        // refresh using NSScreen API.
        self.reloadScreens()
        self.dirty = false
      }
    }
  }

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
    return best ?? screens.first
  }

  private func screen(for host: HostWindow.ID) -> Screen? {
    return screens.first { $0.contains(host: host) }
  }

  func setDefaultWindowRatio(from tab: Terminal.Tab) {
    if (defaultWindowRatio <= 0) {
      let bounds = tab.frame
      if (!bounds.isEmpty) {
        defaultWindowRatio =  bounds.width / bounds.height
      }
    }
  }

  func layout(controller tab: Terminal.Tab, hosts: [HostWindow]) {
    // refresh active screens based on configuration
    setActiveScreens()

    guard screens.contains(where: \.active) else {
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
    layout(hosts: hosts)
  }

  private func layout(hosts: [HostWindow]) {
    assert(!hosts.isEmpty)
    let screens = screens.filter(\.active)
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
      layout(screen: screen, hosts: hostsById)
    }
  }

  private func layout(screen: Screen, hosts: [HostWindow.ID:HostWindow]) {
    guard let grid = screen.grid else { return }

    let bounds = screen.hostsFrame
    let width = bounds.width / CGFloat(grid.columns)
    let height = bounds.height / CGFloat(grid.rows)

    // Layout from top to bottom
    var y = bounds.maxY - height
    for row in grid.grid {
      var x = bounds.minX
      for hostId in row {
        guard let tab = hosts[hostId]?.tab else { continue }

        tab.window.zoomed = false
        tab.window.visible = true
        tab.window.miniaturized = false
        tab.window.frontmost = true
        // Layout from top to bottom
        tab.window.frame = CGRect(x: x, y: y, width: width, height: height)

        x += width
      }
      y -= height
    }
  }

  private func setActiveScreens() {
    // Default to all screens
    screens.forEach { $0.active = true }

    // TODO: active screen config should be converted to UUID list on first load,
    // and then used to keep a stable list of active screens.
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
  }
}

// MARK: -
private struct HostGrid {
  let rows: Int
  let columns: Int

  // caching total host count
  let count: Int
  
  // List of rows
  let grid: [[HostWindow.ID]]

  private func getPosition(of host: HostWindow.ID) -> (Int, Int)? {
    for row in grid.indices {
      if let column = grid[row].firstIndex(of: host) {
        return (row, column)
      }
    }
    return nil
  }

  // resolve coords in grid (row, column).
  //   -> compute next/previous by looking in the grid table.
  func getHostAbove(_ host: HostWindow.ID) -> HostWindow.ID? {
    // row above should always at least as large as the current row.
    guard let (row, column) = getPosition(of: host),
            row > 0, grid[row - 1].endIndex > column else { return nil }

    return grid[row - 1][column]
  }

  func getHostBelow(_ host: HostWindow.ID) -> HostWindow.ID? {
    guard let (row, column) = getPosition(of: host), 
            row + 1 < grid.endIndex, grid[row + 1].endIndex > column else { return nil }

    return grid[row + 1][column]
  }

  func getHostLeft(of host: HostWindow.ID) -> HostWindow.ID? {
    guard let (row, column) = getPosition(of: host), column > 0 else { return nil }

    return grid[row][column - 1]
  }

  func getHostRight(of host: HostWindow.ID) -> HostWindow.ID? {
    guard let (row, column) = getPosition(of: host), column + 1 < grid[row].endIndex else { return nil }

    return grid[row][column + 1]
  }

  // Host Grid factories
  static func byRow(hosts: [HostWindow.ID], rows: Int, columns: Int) -> Self {
    var grid = [[HostWindow.ID]]()

    // Simply fill rows until there is no more hosts
    let end = hosts.endIndex
    var remainings = hosts.startIndex..<end
    while (!remainings.isEmpty) {
      let row = remainings.clamped(to: remainings.startIndex..<remainings.startIndex + columns)
      grid.append(Array(hosts[row]))
      remainings = row.endIndex..<end
    }
    return HostGrid(rows: rows, columns: columns, count: hosts.count, grid: grid)
  }

  // populate by columns instead of populating by rows if row count requested
  // i.e. 5 hosts in 4 columns mode will result in 1 full row of 4 hosts, and a second row with one host
  // in rows mode, it should be 1 row with 2 hosts, and 3 rows with one host.
  static func byColumns(hosts: [HostWindow.ID], rows: Int, columns: Int) -> Self {
    var grid = [[HostWindow.ID]]()

    // count of hosts in the last column
    let fullRows = hosts.count.isMultiple(of: rows) ? rows : hosts.count % rows

    let end = hosts.endIndex
    var remainings = hosts.startIndex..<end
    while (!remainings.isEmpty) {
      let rowLength = grid.count < fullRows ? columns : columns - 1
      let row = remainings.startIndex..<min(end, remainings.startIndex + rowLength)
      grid.append(Array(hosts[row]))
      remainings = row.endIndex..<end
    }

    return HostGrid(rows: rows, columns: columns, count: hosts.count, grid: grid)
  }
}

class Screen {
  let uuid: String // screen UUID.
  // Actual screen visible frame (fullscreen frame)
  var visibleFrame: CGRect

  fileprivate var active: Bool = false

  // Configuration
  private(set) var requestedRows: Int = 0
  private(set) var requestedColumns: Int = 0
  private(set) var requestedFrame: CGRect? // relative to screen frame

  // Computed layout
  var frame: CGRect = CGRect.zero
  fileprivate var reserved: CGFloat = 0

  var hostsFrame: CGRect {
    if (reserved > 0) {
      // Remove space reserved for controller window from screen frame
      let (_, bounds) = frame.divided(atDistance: reserved, from: .minYEdge)
      return bounds
    } else {
      return frame
    }
  }

  fileprivate var grid: HostGrid? = nil

  fileprivate init(uuid: String, visibleFrame frame: CGRect) {
    self.uuid = uuid
    self.visibleFrame = frame
  }

  // Public API

  var hostCount: Int { grid?.count ?? 0 }
  var rows: Int { grid?.rows ?? 0 }
  var columns: Int { grid?.columns ?? 0 }

  fileprivate func contains(host: HostWindow.ID) -> Bool {
    return false
  }

  func set(rows: Int) {
    requestedRows = rows
    requestedColumns = 0
  }

  func set(columns: Int) {
    requestedColumns = columns
    requestedRows = 0
  }

  func set(frame: CGRect, isRelative: Bool) {
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
    guard !hosts.isEmpty else {
      grid = nil
      return
    }

    let count = hosts.count
    if requestedColumns > 0 {
      let columns = min(requestedColumns, count)
      let rows = Int(ceil(Float(count) / Float(columns)))
      grid = HostGrid.byRow(hosts: hosts, rows: rows, columns: columns)
    } else if requestedRows > 0 {
      let rows = min(requestedRows, count)
      let columns = Int(ceil(Float(count) / Float(rows)))
      grid = HostGrid.byColumns(hosts: hosts, rows: rows, columns: columns)
    } else if (ratio > 0) {
      let (rows, columns) = getBestLayout(for: ratio, hosts: count, on: frame.size)
      grid = HostGrid.byRow(hosts: hosts, rows: rows, columns: columns)
    } else {
      grid = nil
    }
  }

  fileprivate var area: CGFloat { frame.width * frame.height }

  func getHostAbove(_ host: HostWindow.ID) -> HostWindow.ID? {
    return grid?.getHostAbove(host)
  }

  func getHostBelow(_ host: HostWindow.ID) -> HostWindow.ID? {
    return grid?.getHostBelow(host)
  }

  func getHostLeft(of host: HostWindow.ID) -> HostWindow.ID? {
    return grid?.getHostLeft(of: host)
  }

  func getHostRight(of host: HostWindow.ID) -> HostWindow.ID? {
    return grid?.getHostRight(of: host)
  }
}

