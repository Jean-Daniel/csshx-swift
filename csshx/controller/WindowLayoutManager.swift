//
//  WindowLayoutManager.swift
//  csshx
//
//  Created by Jean-Daniel Dupas on 23/10/2023.
//

import Foundation

struct WindowLayoutManager {

  private let screen: CGRect
  public private(set) var bounds: CGRect

  var controllerHeight: CGFloat

  init(screens: Array<Int>, bounds: CGRect?, controllerHeight: CGFloat) throws {
    screen = try Screen.visibleFrame(screens: screens)
    // TODO: validate that user requested bounds is compatible with the screen bounds
    self.bounds = bounds ?? screen
    self.controllerHeight = controllerHeight
  }

  mutating func layout(controller tab: Terminal.Tab) {
    let screen = bounds

    tab.window.miniaturized = false
    tab.window.frame = CGRect(origin: screen.origin, size: CGSize(width: screen.width, height: controllerHeight))

    // Now check the height of the terminal window in case it's larger than
    // expected, if so, move it off the bottom of the screen if possible
    let real = tab.window.size
    if (real.y > controllerHeight) {
      tab.window.origin = CGPoint(x: screen.origin.x, y: screen.origin.y - (real.y - controllerHeight))
      // update internal value used to compute other windows layout
      controllerHeight = real.y
    }
  }
}

private struct Screen {

  static func visibleFrame(screens: Array<Int>) throws -> CGRect {
    // Default to main screen (screen with the active window)
    if (screens.isEmpty) {
      guard let screen = NSScreen.main else {
        throw POSIXError(.ENODEV)
      }
      return screen.visibleFrame
    }

    let displays = NSScreen.screens
    guard !displays.isEmpty else {
      throw POSIXError(.ENODEV)
    }

    if (screens.count == 1) {
      let idx = screens[0]
      guard 1 < idx && idx <= displays.count else {
        logger.warning("screen number must be in range [1;\(displays.count)]")
        // default to main screen (with fallback to primary screen)
        return (NSScreen.main ?? displays[0]).visibleFrame
      }
      return displays[idx - 1].visibleFrame
    }

    // TODO: Multi screen support
    // Should return a list of visible frames sorted from "left to right"
    throw POSIXError(.ENOTSUP)
  }
}


