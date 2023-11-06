//
//  LayoutManager.swift
//  csshx-tests
//
//  Created by Jean-Daniel Dupas on 28/10/2023.
//

import XCTest

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
}
