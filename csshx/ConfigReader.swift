//
//  ConfigReader.swift
//  csshx
//
//  Created by Jean-Daniel Dupas on 14/10/2023.
//

import Foundation
import RegexBuilder

// Host parsing:
// 1. Create a list of target from host files, and arguments.
// 2. Expands/Resolve hosts by:
//   - looking up if the host is a cluster.
//   - trying to expand the hostname if this is an hostname template.
//   - else assume this is an hostname and insert is as is.


extension Settings {

  // Load settings and create HostList used to resolve target hosts.
  static func load(_ hosts: [String], options: Config, sshOptions: SSHOptions, layoutOptions: LayoutOptions) async throws -> (Settings, HostList) {
    var hostList = HostList()
    var settings = Settings()

    for host in hosts {
      try hostList.add(host, command: nil)
    }

    do {
      try await hostList.load(clustersFile: URL(filePath: "/etc/clusters"))
    } catch CocoaError.fileNoSuchFile {
      logger.debug("/etc/clusters does not exists. Skipping it.")
    } catch {
      throw error
    }

    // Load predefined csshrc files
    for file in ["/etc/csshrc", "~/.csshrc"] {
      do {
        try await settings.load(csshrc: URL(filePath: file), hosts: &hostList)
      } catch CocoaError.fileNoSuchFile {
        logger.debug("\(file) does not exists. Skipping it.")
      } catch {
        throw error
      }
    }
    
    for file in options.hostFiles {
      // Failing if file specified by user does not exists.
      try await hostList.load(hostFile: URL(filePath: file))
    }

    for file in options.configFiles {
      // Failing if file specified by user does not exists.
      try await settings.load(csshrc: URL(filePath: file), hosts: &hostList)
    }

    options.override(&settings)
    sshOptions.override(&settings)
    layoutOptions.override(&settings)
    return (settings, hostList)
  }

  mutating func load(csshrc file: URL, hosts: inout HostList) async throws {
    var clusters = Set<String>()
    var settings = [String:String]()

    let comment = /#.*$/
    for try await line in file.lines {
      guard let match = line.replacing(comment, with: "").wholeMatch(of: /^\s*(\S+)\s*=\s*(.*?)\s*$/) else {
        logger.warning("invalid csshrc line: \(line)")
        continue
      }
      let key = match.output.1
      let value = match.output.2
      if (key == "extra_cluster_file") {
        for extra in value.split(separator: /\s*,\s*/) {
          try await hosts.load(clustersFile: URL(filePath: String(extra)))
        }
      } else if (key == "clusters") {
        // Insert clusters into the clusters set.
        clusters.formUnion(value.split(separator: /\s+/).map { String($0) })
      } else if (key == "hosts") {
        // load host file
        for extra in value.split(separator: /\s*,\s*/) {
          try await hosts.load(hostFile: URL(filePath: String(extra)))
        }
      } else {
        settings[String(key)] = String(value)
      }
    }

    for cluster in clusters {
      // For each cluster declared in the settings
      guard let clusterHosts = settings[cluster]?.split(separator: /\s+/), !clusterHosts.isEmpty else {
        logger.warning("No hosts defined for cluster \(cluster) in \(file)")
        continue
      }
      hosts.add(clusterHosts.map(String.init), to: cluster)
    }

    for (key, value) in settings where !clusters.contains(key) {
      try set(String(key), value: String(value))
    }
  }
}

