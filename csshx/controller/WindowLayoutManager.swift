//
//  WindowLayoutManager.swift
//  csshx
//
//  Created by Jean-Daniel Dupas on 23/10/2023.
//

import Foundation
import AppKit

// TODO: Listen for screen configuration change notification
struct WindowLayoutManager {

  struct Config {
    var rows: Int = 0
    var columns: Int = 0
    var screens: Array<Int> = []
    var screenBounds: CGRect? = nil
    var controllerHeight: CGFloat = 87 // Pixels ?
  }

  private var config: Config

  private var layoutBounds: [CGRect]
  private var defaultWindowRatio: Double = 0

  init(config: Config) {
    self.config = config
    // TODO: validate that user requested bounds is compatible with the screen bounds
    layoutBounds = (try? Screen.visibleFrames(screens: config.screens)) ?? []
  }

  var rows: Int {
    get { config.rows }
    set { config.rows = newValue }
  }

  var columns: Int {
    get { config.columns }
    set { config.columns = newValue }
  }

  mutating func setDefaultWindowRatio(from tab: Terminal.Tab) {
    if (defaultWindowRatio <= 0) {
      let bounds = tab.frame()
      if (!bounds.isEmpty) {
        defaultWindowRatio =  bounds.width / bounds.height
      }
    }
  }

  mutating func layout(controller tab: Terminal.Tab, hosts: [Terminal.Tab]) {
    guard !layoutBounds.isEmpty else {
      logger.warning("failed to compute screen bounds. Skipping layout pass.")
      return
    }

    tab.window.miniaturized = false

    // FIXME: find on which screen the controller currently is.
    tab.window.frame = CGRect(origin: layoutBounds[0].origin,
                              size: CGSize(width: layoutBounds[0].width, height: config.controllerHeight))

    // TODO: check set resulting frame ?
    guard !hosts.isEmpty else { return }

    layout(hosts: hosts, screens: layoutBounds, space: tab.space)
  }

  private mutating func layout(hosts: [Terminal.Tab], screens: [CGRect], space: Int32) {
    assert(!hosts.isEmpty)
    assert(!screens.isEmpty)

    // TODO: create and save grid for selection handling.

    var hostsByScreen: [[Terminal.Tab]] = []
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
    for (hosts, screen) in zip(hostsByScreen, screens) {
      if (first) {
        // If main screen -> remove controller frame
        let (_, bounds) = screen.divided(atDistance: config.controllerHeight, from: .minYEdge)
        layout(hosts: hosts, on: bounds, space: space)
        first = false
      } else {
        layout(hosts: hosts, on: screen, space: space)
      }
    }
  }

  // Compute number of rows
  private func getGrid(for hosts: [Terminal.Tab], on screen: CGRect) -> (Int, Int) {
    let count = hosts.count
    if config.rows > 0 {
      let rows = min(config.rows, hosts.count)
      return (rows, Int(ceil(Float(count) / Float(rows))))
    }
    if config.columns > 0 {
      let columns = min(config.columns, hosts.count)
      return (Int(ceil(Float(count) / Float(columns))), columns)
    }

    guard defaultWindowRatio > 0 else { return (0, 0) }
    return getBestLayout(for: defaultWindowRatio, hosts: count, on: screen)
  }

  private mutating func layout(hosts: [Terminal.Tab], on screen: CGRect, space: Int32) {
    let (rows, columns) = getGrid(for: hosts, on: screen)
    let width = screen.width / CGFloat(columns)
    let height = screen.height / CGFloat(rows)

    for (idx, host) in hosts.enumerated() {
      let x = CGFloat(idx % columns) * width
      let y = CGFloat(idx / columns) * height
      // Move to controller space if needed
      if space > 0 {
        host.space = space
      }
      host.window.zoomed = false
      host.window.visible = true
      host.window.miniaturized = false
      host.window.frontmost = true
      host.window.frame = CGRect(x: screen.minX + x, y: screen.minY + y, width: width, height: height)
    }
  }
}

private struct Screen {

  /// Returns a tuple of visible frame, and the main screen index.
  static func visibleFrames(screens: Array<Int>) throws -> [CGRect] {
    // Default to main screen (screen with the active window)
    if (screens.isEmpty) {
      guard let screen = NSScreen.main else {
        throw POSIXError(.ENODEV)
      }
      return [screen.visibleFrame]
    }

    let displays = NSScreen.screens
    guard !displays.isEmpty else {
      throw POSIXError(.ENODEV)
    }

    var used = Set<Int>()
    var frames = [CGRect]()
    for idx in screens {
      guard (1...displays.count).contains(idx) else {
        logger.warning("screen number must be in range [1;\(displays.count)]")
        continue
      }
      guard !used.contains(idx - 1) else {
        continue
      }
      used.insert(idx - 1)
      frames.append(displays[idx - 1].visibleFrame)
    }

    guard !frames.isEmpty else {
      // default to main screen (with fallback to primary screen)
      return [(NSScreen.main ?? displays[0]).visibleFrame]
    }

    // TODO: sort screen from left to right ?
    return frames
  }
}


