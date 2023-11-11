//
//  csshx_tests.swift
//  csshx-tests
//
//  Created by Jean-Daniel Dupas.
//

import XCTest
import OSLog

// @testable import CsshxCore

final class csshx_tests: XCTestCase {

  override func setUpWithError() throws {
    // Put setup code here. This method is called before the invocation of each test method in the class.
  }

  override func tearDownWithError() throws {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
  }

  func testParseUserHostPort() throws {
    var (user, host, port) = try "www.example.com".parseUserHostPort()
    XCTAssertNil(user)
    XCTAssertEqual("www.example.com", host)
    XCTAssertNil(port)

    (user, host, port) = try "www.example.com:1234".parseUserHostPort()
    XCTAssertNil(user)
    XCTAssertEqual("www.example.com", host)
    XCTAssertEqual("1234", port)

    (user, host, port) = try "john@www.example.com:[22-24]".parseUserHostPort()
    XCTAssertEqual("john", user)
    XCTAssertEqual("www.example.com", host)
    XCTAssertEqual("[22-24]", port)
  }

}
