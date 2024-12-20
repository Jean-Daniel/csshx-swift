//
//  HostList.swift
//  csshx
//
//  Created by Jean-Daniel Dupas.
//

import Foundation

import System
import RegexBuilder

struct Target: Equatable {
  let user: String?
  let hostname: String // may be an host template.
  let port: UInt16?
  let command: String?
  
  var connectionString: String {
    var cnt = hostname
    if let user {
      cnt.insert("@", at: cnt.startIndex)
      cnt.insert(contentsOf: user, at: cnt.startIndex)
    }
    if let port {
      cnt.append(":")
      cnt.append(String(port))
    }
    return cnt
  }
}

/// HostList is use to convert clusters/hosts parameters into an actual host list.
struct HostList {
  
  private struct HostSpec {
    let user: String?
    let hostname: String
    let port: String? // may be a port range
    let command: String?
    
    init(user: String?, hostname: String, port: String?, command: String?) {
      self.user = user
      self.hostname = hostname
      self.port = port
      self.command = command
    }
    
    init<S: StringProtocol>(host: S, command: String?) throws where S.SubSequence == Substring {
      (user, hostname, port) = try host.parseUserHostPort()
      self.command = command
    }
    
    func with(hostname: String) -> HostSpec {
      return HostSpec(user: user, hostname: hostname, port: port, command: command)
    }
  }
  
  private var hosts = [HostSpec]()
  private var clusters = [String:[String]]()
  
  func getHosts(limit: Int = 2048) throws -> [Target] {
    var resolved = [Target]()
    for host in hosts {
      try expands(host, limit: limit, into: &resolved)
    }
    return resolved
  }

  nonisolated(unsafe)
  private static let repeatPattern = Regex {
    Capture(OneOrMore(.any, .reluctant))
    "+"
    Capture {
      OneOrMore(.digit)
    } transform: { Int($0)! }
  }
  
  // Evaluate "repeat" patterns and fallback to _expand()
  private func expands(_ host: HostSpec, limit: Int, into: inout [Target]) throws {
    // 192.168.0.1+3
    
    // Then, check for repeat pattern
    if let match = host.hostname.wholeMatch(of: Self.repeatPattern) {
      // expand single entry, and then repeat
      let count = match.output.2
      
      // Ensure repeat count is greater than 1, and that this is not a recursive pattern.
      guard count > 1,
            match.output.1.wholeMatch(of: Self.repeatPattern) == nil else {
        logger.warning("invalid repeat pattern: \(host.hostname, privacy: .public)")
        throw POSIXError(.EINVAL)
      }
      
      var result = [Target]()
      try _expands(host.with(hostname: String(match.output.1)), limit: (limit - into.count) / count, into: &result)
      for target in result {
        into.append(contentsOf: repeatElement(target, count: count))
      }
    } else {
      try _expands(host, limit: limit, into: &into)
    }
  }
  
  private func _expands(_ host: HostSpec, limit: Int, into: inout [Target]) throws {
    // 192.168.0.0/24
    // 192.168.0.[0-255]
    // 192.168.0.[0-20,13]
    // 192.168.[0-2].[255,254]
    // 192.168.[0-2].0/24
    
    // Try cluster expansion
    if let clusterHosts = clusters[host.hostname] {
      logger.debug("Expand cluster: \(host.hostname, privacy: .public) => \(clusterHosts, privacy: .public)\n")
      // add cluster host (expanding them if needed)
      for host in clusterHosts {
        // supports repeat expansion in cluster expansion -> call to expands (and not _expands)
        try expands(HostSpec(host: host, command: nil), limit: limit, into: &into)
      }
      return
    }
    
    // Expand all ranges in the hostname.
    if let match = host.hostname.wholeMatch(of: /(.*)\[(.*)\](.*)/.repetitionBehavior(.reluctant)) {
      let prefix = match.output.1
      let suffix = match.output.3
      guard let values = parse(ranges: String(match.output.2), limit: limit - into.count) else {
        logger.warning("invalid range definition in: \(host.hostname, privacy: .public)")
        throw POSIXError(.EINVAL)
      }
      for s in values {
        try _expands(host.with(hostname: "\(prefix)\(s)\(suffix)"), limit: limit, into: &into)
      }
      return
    }
    
    // If not range remaining, try to interpret it as an IP network notation.
    // Loosy regex as '/' is not valid in an hostname.
    if host.hostname.wholeMatch(of: /(.+)\/(.+)/.repetitionBehavior(.reluctant)) != nil {
      guard let values = _expand(ip: host.hostname, limit: limit - into.count) else {
        logger.warning("invalid IP address: \(host.hostname, privacy: .public)")
        throw POSIXError(.EINVAL)
      }
      for s in values {
        try _expands(host.with(hostname: s), limit: limit, into: &into)
      }
      return
    }
    
    // Finally, try to expand port range, and create resulting Target.
    guard let p = host.port else {
      into.append(Target(user: host.user, hostname: host.hostname, port: nil, command: host.command))
      return
    }
    
    let ports: [String]?
    if p.hasPrefix("[") && p.hasSuffix("]") {
      ports = parse(ranges: String(p.dropFirst().dropLast()), limit: limit - into.count)
    } else {
      ports = [p]
    }
    
    guard let ports else {
      logger.warning("invalid port range: \(host.hostname, privacy: .public):\(p, privacy: .public)")
      throw POSIXError(.EINVAL)
    }
    
    for port in ports {
      guard let portnum = UInt16(port) else {
        logger.warning("invalid port: \(port, privacy: .public)")
        throw POSIXError(.EINVAL)
      }
      into.append(Target(user: host.user, hostname: host.hostname, port: portnum, command: host.command))
    }
  }
  
  private func _expand(ip: String, limit: Int) -> [String]? {
    var addr = in_addr()
    let bits = inet_net_pton(AF_INET, ip, &addr, MemoryLayout.size(ofValue: addr))
    guard bits > 0 else {
      return nil
    }
    let mask: UInt32 = ~(0xffffffff >> bits)
    let start = UInt32(bigEndian: addr.s_addr)
    // compute last addr by applying netmask.
    let end = (start & mask) + ~mask
    guard start < end else {
      logger.debug("invalid range. start must be less than end: \(ip, privacy: .public)")
      return nil
    }
    guard (start...end).count <= limit else {
      logger.debug("range too large (\(end - start) > \(limit): \(ip, privacy: .public)")
      return nil
    }
    var addrs = [String]()
    for i in start...end {
      addr.s_addr = i.bigEndian
      // return addr create using inet_ntoa
      guard let str = inet_ntoa(addr) else {
        return nil
      }
      addrs.append(String(cString: str))
    }
    return addrs
  }
  
  // range:
  // • [foo,bar,misc]
  // • [12-24]
  // • [a-f]
  // • [foo,1-12,b-g]
  private func parse(ranges: String, limit: Int) -> [String]? {
    // split on comma, and then parse individual range if they contains '-'
    if ranges.contains(",") {
      var result = [String]()
      for range in ranges.split(separator: ",") {
        guard parse(range: String(range), limit: limit, into: &result) else {
          return nil
        }
      }
      return result
    }
    
    // single range or single value
    var result = [String]()
    guard parse(range: ranges, limit: limit, into: &result) else {
      return nil
    }
    return result
  }

  nonisolated(unsafe)
  private static let intRange = Regex {
    Capture(OneOrMore(.digit)) { Int($0)! }
    "-"
    Capture(OneOrMore(.digit)) { Int($0)! }
  }

  nonisolated(unsafe)
  private static let alphaRange = Regex {
    ChoiceOf {
      Regex {
        Capture("a"..."z") { $0.first!.asciiValue! }
        "-"
        Capture("a"..."z") { $0.first!.asciiValue! }
      }
      Regex {
        Capture("A"..."Z") { $0.first!.asciiValue! }
        "-"
        Capture("A"..."Z") { $0.first!.asciiValue! }
      }
    }
  }
  
  // start-end
  private func parse(range: String, limit: Int, into: inout [String]) -> Bool {
    // single word -> return change unchanged.
    if range.wholeMatch(of: OneOrMore(.word)) != nil {
      guard limit >= into.count + 1 else {
        // limit reached
        return false
      }
      into.append(range)
      return true
    } else if let match = range.wholeMatch(of: Self.intRange) {
      let start = match.output.1
      let end = match.output.2
      guard start < end else {
        logger.debug("invalid range. start must be less than end: \(range, privacy: .public)")
        return false
      }
      guard (start...end).count <= limit else {
        logger.debug("range too large (\(end - start) > \(limit): \(range, privacy: .public)")
        return false
      }
      for i in start...end {
        into.append(String(i))
      }
      return true
    } else if let match = range.wholeMatch(of: Self.alphaRange) {
      // if start and end are lowercase alpha -> return lower char range
      // if start and end are uppercase alpha -> return upper char range
      guard let start = match.1 ?? match.3, let end = match.2 ?? match.4 else {
        fatalError("pattern matches but output is nil ?")
      }
      guard start < end else {
        logger.debug("invalid range. start must be less than end: \(range, privacy: .public)")
        return false
      }
      guard (start...end).count <= limit else {
        logger.debug("range too large (\(end - start) > \(limit): \(range, privacy: .public)")
        return false
      }
      for i in start...end {
        into.append(String(UnicodeScalar(i)))
      }
      return true
    }
    
    return false
  }
  
  mutating func add(_ host: String, command: String?) throws {
    hosts.append(try HostSpec(host: host, command: command))
  }
  
  mutating func add(_ host: String, to cluster: String) {
    if (clusters[cluster]?.append(host) == nil) {
      clusters[cluster] = [host]
    }
  }
  
  mutating func add(_ hosts: [String], to cluster: String) {
    if (clusters[cluster]?.append(contentsOf: hosts) == nil) {
      clusters[cluster] = hosts
    }
  }

  nonisolated(unsafe)
  private static let commentExpr = /#.*$/

  nonisolated(unsafe)
  private static let hostFileLine = Regex {
    Capture {
      OneOrMore(.whitespace.inverted)
    }
    Optionally {
      OneOrMore(.whitespace)
      Capture {
        ZeroOrMore(.any)
      }
    }
  }
  
  mutating func load(hostFile file: FilePath) throws {
    // Read each line of the data as it becomes available.
    try file.readLines { line in
      // Strip comment (remove anything after '#')
      guard let match = line.replacing(Self.commentExpr, with: "").wholeMatch(of: Self.hostFileLine) else {
        return
      }
      try add(String(match.output.1), command: match.output.2.flatMap(String.init))
    }
  }
  
  mutating func load(clustersFile file: FilePath) throws {
    // Read each line of the data as it becomes available.
    try file.readLines { line in
      // Strip comment (remove anything after '#')
      let components = line.replacing(Self.commentExpr, with: "")
      // Split using all whitespaces as delimiter
        .split(separator: OneOrMore(.whitespace))
      
      guard components.count > 1 else { return }
      
      // the first entry is a cluster name, following entries are matching hosts
      let cluster = String(components.first!)
      let hosts = components.dropFirst()
      // save cluster into config clusters
      add(hosts.map(String.init), to: cluster)
    }
  }
}

nonisolated(unsafe)
private let hostFormat = Regex {
  Optionally {
    Regex {
      Capture(OneOrMore(.any, .reluctant))
      "@"
    }
  }
  Capture(OneOrMore(.any, .reluctant))
  Optionally {
    Regex {
      ":"
      Capture {
        OneOrMore(.any)
      }
    }
  }
}

extension StringProtocol where Self.SubSequence == Substring {
  func parseUserHostPort() throws -> (String?, String, String?) {
    // Formats:
    //   hostname
    //   hostname:port
    //   user@hostname
    //   user@hostname:port
    guard let result = wholeMatch(of: hostFormat) else {
      throw CocoaError(.formatting)
    }
    return (result.output.1.flatMap(String.init), String(result.output.2), result.output.3.flatMap(String.init));
  }
}
