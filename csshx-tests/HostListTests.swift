//
//  HostListTests.swift
//  csshx-tests
//
//  Created by Jean-Daniel Dupas on 16/10/2023.
//

import XCTest

final class HostListTests: XCTestCase {

  func testRange() throws {
    var hosts = HostList()
    try hosts.add("host-[prod,dev][a-c]", command: nil)
    try hosts.add("192.168.[0,2-3].[1-2,3-5]", command: nil)

    let targets = Set(try hosts.getHosts().map { $0.hostname })
    XCTAssertEqual(6 + 15, targets.count)

    for i in [ "prod", "dev" ] {
      for j in [ "a", "b", "c" ] {
        XCTAssertTrue(targets.contains("host-\(i)\(j)"))
      }
    }

    for i in [ "0", "2", "3" ] {
      for j in [ "1", "2", "3", "4", "5" ] {
        XCTAssertTrue(targets.contains("192.168.\(i).\(j)"))
      }
    }
  }

  func testHostIPRange() throws {
    var hosts = HostList()
    try hosts.add("1.2.3.0/28", command: nil)
    try hosts.add("1.2.3.75/28", command: nil)

    let targets = Set(try hosts.getHosts().map { $0.hostname })
    XCTAssertEqual(16 + 5, targets.count)
    for idx in 0..<16 {
      XCTAssertTrue(targets.contains("1.2.3.\(idx)"))
    }
    for idx in 75..<80 {
      XCTAssertTrue(targets.contains("1.2.3.\(idx)"))
    }
  }

  func testHostIntRange() throws {
    var hosts = HostList()
    try hosts.add("server-[1-3].example.com", command: nil)

    let targets = Set(try hosts.getHosts().map { $0.hostname })
    XCTAssertEqual(3, targets.count)
    for idx in 1...3 {
      XCTAssertTrue(targets.contains("server-\(idx).example.com"))
    }
  }

  func testHostAlphaRange() throws {
    var hosts = HostList()
    try hosts.add("server-[d-f].example.com", command: nil)
    try hosts.add("server-[F-H].example.com", command: nil)

    let targets = Set(try hosts.getHosts().map { $0.hostname })
    XCTAssertEqual(6, targets.count)
    for c in [ "d", "e", "f", "F", "G", "H" ] {
      XCTAssertTrue(targets.contains("server-\(c).example.com"))
    }
  }

  func testPortRange() throws {
    var hosts = HostList()
    try hosts.add("host-[prod,dev][a-c]:[12-16]", command: nil)

    let targets = try hosts.getHosts(limit: 30)
    XCTAssertEqual(30, targets.count)
    for i in [ "prod", "dev" ] {
      for j in [ "a", "b", "c" ] {
        for port in 12...16 {
          XCTAssertTrue(targets.contains(hostname: "host-\(i)\(j)", port: port))
        }
      }
    }

    XCTAssertThrowsError(try hosts.getHosts(limit: 29))
  }

  func testRepeat() throws {
    var hosts = HostList()
    try hosts.add("host-[prod,dev][a-c]+3", command: nil)

    let targets = NSCountedSet(array: try hosts.getHosts().map { $0.hostname })
    // count returns the number of unique keys
    XCTAssertEqual(6, targets.count)

    for i in [ "prod", "dev" ] {
      for j in [ "a", "b", "c" ] {
        XCTAssertEqual(3, targets.count(for: "host-\(i)\(j)"))
      }
    }
  }

  func testHostLimit() throws {
    var hosts = HostList()
    try hosts.add("hostname[0-63]", command: nil)
    try hosts.add("server[0-63]", command: nil)

    let targets = try hosts.getHosts()
    XCTAssertEqual(128, targets.count)
    XCTAssertNoThrow(try hosts.getHosts(limit: 128))
    XCTAssertThrowsError(try hosts.getHosts(limit: 127))
  }

  func testRecursiveClusterExpansion() throws {
    var hosts = HostList()
    hosts.add("workers-[a-b]", to: "workers")
    hosts.add("worker-[1-3].cluster", to: "workers-a")
    hosts.add("worker-[4-6].cluster", to: "workers-b")
    try hosts.add("workers+2", command: nil)

    let targets = NSCountedSet(array: try hosts.getHosts().map { $0.hostname })
    // count returns the number of unique keys
    XCTAssertEqual(6, targets.count)

    for idx in 1...6 {
      XCTAssertEqual(2, targets.count(for: "worker-\(idx).cluster"))
    }
  }
}

private extension Array<Target> {

  func contains(hostname: String, port: Int) -> Bool {
    return contains { $0.hostname == hostname && ($0.port ?? 0) == port }
  }
}
