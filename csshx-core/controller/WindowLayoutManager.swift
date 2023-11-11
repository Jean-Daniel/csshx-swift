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
    return screens.first { $0.hosts.contains(host) }
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
    layout(hosts: hosts, space: tab.space)
  }

  private func layout(hosts: [HostWindow], space: Int32) {
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
      layout(screen: screen, space: space, hosts: hostsById)
    }
  }

  private func layout(screen: Screen, space: Int32, hosts: [HostWindow.ID:HostWindow]) {
    guard screen.rows > 0, screen.columns > 0 else { return }

    let bounds = screen.hostsFrame
    let width = bounds.width / CGFloat(screen.columns)
    let height = bounds.height / CGFloat(screen.rows)

    var layout = screen.grid()
    for hostId in screen.hosts {
      guard let host = hosts[hostId] else { return }

      let tab = host.tab
      // Move to controller space if needed
      if space > 0 {
        tab.space = space
      }
      tab.window.zoomed = false
      tab.window.visible = true
      tab.window.miniaturized = false
      tab.window.frontmost = true

      let (column, row) = layout.next()
      let x = CGFloat(column) * width
      let y = CGFloat(row) * height
      // Layout from top to bottom
      tab.window.frame = CGRect(x: bounds.minX + x, y: bounds.maxY - height - y, width: width, height: height)
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

private protocol ScreenGrid {
  mutating func next() -> (Int, Int)
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

  fileprivate var hosts: [HostWindow.ID] = []

  fileprivate(set) var rows: Int = 0
  fileprivate(set) var columns: Int = 0

  fileprivate init(uuid: String, visibleFrame frame: CGRect) {
    self.uuid = uuid
    self.visibleFrame = frame
  }

  // Public API

  var count: Int { hosts.count }
  
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
    if requestedColumns > 0 {
      columns = min(requestedColumns, count)
      rows = Int(ceil(Float(count) / Float(columns)))
    } else if requestedRows > 0 {
      rows = min(requestedRows, count)
      columns = Int(ceil(Float(count) / Float(rows)))
    } else if (ratio > 0) {
      (rows, columns) = getBestLayout(for: ratio, hosts: count, on: frame.size)
    } else {
      rows = 0
      columns = 0
    }
  }

  struct ColumnsLayout: ScreenGrid {
    let columns: Int
    private var cursor = 0

    init(columns: Int) {
      self.columns = columns
    }

    mutating func next() -> (Int, Int) {
      let pos = cursor
      cursor += 1
      return (pos % columns, pos / columns)
    }
  }

  struct RowsLayout: ScreenGrid {
    let rows: Int
    let columns: Int
    private let lastColumnsCount: Int

    private var column = 0
    private var row = 0

    init(rows: Int, columns: Int, hostCount: Int) {
      self.rows = rows
      self.columns = columns
      // count of hosts in the last column
      lastColumnsCount = hostCount.isMultiple(of: rows) ? rows : hostCount % rows
    }

    mutating func next() -> (Int, Int) {
      let x = column
      let y = row
      
      // Compute next position
      if (column == columns - 1) // was last column
          || (column == columns - 2 && row >= lastColumnsCount) { // second last column, and last column is empty for this row.
        // wrap around
        row += 1
        column = 0
      } else {
        column += 1
      }

      return (x, y)
    }
  }

  fileprivate func grid() -> any ScreenGrid {
    if (requestedRows > 0 && requestedColumns <= 0) {
      // populate by columns instead of populating by rows if row count requested
      // i.e. 5 hosts in 4 columns mode will result in 1 full row of 4 hosts, and a second row with one host
      // in rows mode, it should be 1 row with 2 hosts, and 3 rows with one host.
      return RowsLayout(rows: rows, columns: columns, hostCount: hosts.count)
    } else {
      return ColumnsLayout(columns: columns)
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
}



