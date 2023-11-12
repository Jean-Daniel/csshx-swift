//
//  LayoutManager.swift
//  csshx-tests
//
//  Created by Jean-Daniel Dupas.
//

import XCTest

// @testable import CsshxCore

final class WindowLayoutManagerTests: XCTestCase {

  func testSimpleLayout() throws {
    var (rows, columns) = getBestLayout(for: 16.0 / 9.0, hosts: 23, on: CGSize(width: 1024, height: 768))
    XCTAssertEqual(6, rows)
    XCTAssertEqual(4, columns)

    (rows, columns) = getBestLayout(for: 3.0 / 2.0, hosts: 23, on: CGSize(width: 1024, height: 768))
    XCTAssertEqual(5, rows)
    XCTAssertEqual(5, columns)
  }

  func testSingleHost() throws {
    let (rows, columns) = getBestLayout(for: 16.0 / 9.0, hosts: 1, on: CGSize(width: 1024, height: 768))
    XCTAssertEqual(1, rows)
    XCTAssertEqual(1, columns)    
  }

  // Three hosts should not fallback to 4x4, as it waste a quarter of the screen space,
  // even if the ratio is better.
  func testThreeHosts() throws {
    let (rows, columns) = getBestLayout(for: 16.0 / 9.0, hosts: 3, on: CGSize(width: 1024, height: 768))
    XCTAssertEqual(3, rows)
    XCTAssertEqual(1, columns)
  }

  func testMatchingCount() throws {
    // Best ratio is 5x5, but should still match 6x4 
    let (rows, columns) = getBestLayout(for: 1280.0 / 720.0, hosts: 24, on: CGSize(width: 1728, height: 1000))
    XCTAssertEqual(6, rows)
    XCTAssertEqual(4, columns)
  }
}
