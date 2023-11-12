//
//  ConfigReader.swift
//  csshx
//
//  Created by Jean-Daniel Dupas.
//

import Foundation
import System
import RegexBuilder


extension Settings {
  
  // Load settings and create HostList used to resolve target hosts.
  static func load(_ hosts: [String], options: Config, sshOptions: SSHOptions, layoutOptions: LayoutOptions) throws -> (Settings, HostList) {
    var hostList = HostList()
    var settings = Settings()
    
    for host in hosts {
      try hostList.add(host, command: nil)
    }
    
    do {
      try hostList.load(clustersFile: "/etc/clusters")
    } catch CocoaError.fileNoSuchFile {
      logger.debug("/etc/clusters does not exists. Skipping it.")
    } catch {
      throw error
    }
    
    // Load predefined csshrc files
    for file in ["/etc/csshrc", "~/.csshrc"] {
      do {
        try settings.load(csshrc: FilePath(file), hosts: &hostList)
      } catch CocoaError.fileNoSuchFile {
        logger.debug("\(file, privacy: .public) does not exists. Skipping it.")
      } catch {
        throw error
      }
    }
    
    for file in options.hostFiles {
      // Failing if file specified by user does not exists.
      try hostList.load(hostFile: FilePath(file))
    }
    
    for file in options.configFiles {
      // Failing if file specified by user does not exists.
      try settings.load(csshrc: FilePath(file), hosts: &hostList)
    }
    
    options.override(&settings)
    sshOptions.override(&settings)
    layoutOptions.override(&settings)
    return (settings, hostList)
  }
  
  mutating func load(csshrc file: FilePath, hosts: inout HostList) throws {
    var clusters = Set<String>()
    var settings = [String:String]()
    
    let comment = /#.*$/
    try file.readLines { line in
      guard let match = line.replacing(comment, with: "").wholeMatch(of: /^\s*(\S+)\s*=\s*(.*?)\s*$/) else {
        if !line.isEmpty {
          logger.warning("invalid csshrc line: \(line)")
        }
        return
      }
      let key = match.output.1
      let value = match.output.2
      if (key == "extra_cluster_file") {
        for extra in value.split(separator: /\s*,\s*/) {
          try hosts.load(clustersFile: FilePath(String(extra)))
        }
      } else if (key == "clusters") {
        // Insert clusters into the clusters set.
        clusters.formUnion(value.split(separator: /\s+/).map { String($0) })
      } else if (key == "hosts") {
        // load host file
        for extra in value.split(separator: /\s*,\s*/) {
          try hosts.load(hostFile: FilePath(String(extra)))
        }
      } else {
        settings[String(key)] = String(value)
      }
    }
    
    for cluster in clusters {
      // For each cluster declared in the settings
      guard let clusterHosts = settings[cluster]?.split(separator: /\s+/), !clusterHosts.isEmpty else {
        logger.warning("No hosts defined for cluster \(cluster, privacy: .public) in \(file, privacy: .public)")
        continue
      }
      hosts.add(clusterHosts.map(String.init), to: cluster)
    }
    
    for (key, value) in settings where !clusters.contains(key) {
      try set(String(key), value: String(value))
    }
  }
}

