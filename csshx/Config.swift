//
//  Config.swift
//  csshx
//
//  Created by Jean-Daniel Dupas on 06/10/2023.
//

import ArgumentParser
import Foundation
import RegexBuilder

struct Config: ParsableArguments {

  @Option(name: .customLong("config")) var configs: [String] = []

  @Option(name: [.short, .long]) var login: String?

  @Option(name: [.customLong("sock")]) var socket: String?

  @Option(name: [.short, .customLong("tile_x")]) var x: Int = 0
  @Option(name: [.short, .customLong("tile_y")]) var y: Int = 0

  @Flag(name: [.long, .customLong("ping")]) var pingTest = false
  @Option var pingTimeout: Int = 2

  @Option var screen: Int = 0
  @Option var space: Int = 0
  @Option var sshArgs: String?
  @Option var debug: Int = 0

  @Option var sessionMax: Int = 256
  @Flag var version = false

  @Option var ssh: String = "ssh"
  @Option var hosts: [String] = []

  @Option var remoteCommand: String?
  @Option var masterSettingsSet: String?
  @Option var slaveSettingsSet: String?

  @Option(name: [.short, .long]) var interleave: Int = 0
  @Flag var sortHosts = false

  private var clusters = [String:[String]]()

  mutating func load() async throws {
    try await load_clusters(at: "/etc/clusters");
    // $obj->load_csshrc($_) foreach ("/etc/csshrc", "$ENV{HOME}/.csshrc");

    // Load extra hosts and configurations
    // $obj->load_hosts($_)  foreach @{$obj->{hosts}};
    // $obj->load_csshrc($_) foreach @{$obj->{config}};
  }

  mutating func load_clusters(at path: String) async throws {
    let file = URL(filePath: path)
    do {
      let comment = /#.*$/
      // Read each line of the data as it becomes available.
      for try await line in file.lines {
        // Strip comment (remove anything after '#')
        let components = line.replacing(comment, with: "")
        // Split using all whitespaces as delimiter
          .split(separator: /\s+/)

        guard components.count > 1 else { continue }

        // the first entry is a cluster name, following entries are matching hosts
        let cluster = String(components.first!)
        let hosts = components.dropFirst()
        // save cluster into config clusters
        if (clusters[cluster]?.append(contentsOf: hosts.map { String($0) }) == nil) {
          clusters[cluster] = hosts.map { String($0) }
        }
      }
    } catch CocoaError.fileNoSuchFile {
      logger.debug("\(path) does not exists. Skipping it.")
    } catch {
      print ("Error: \(error)")
    }
  }

  mutating func load_csshrc(at path: String) async throws {
    let file = URL(filePath: path)
    var clusters = [String]()
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
          try await load_csshrc(at: String(extra))
        }
      } else if (key == "clusters") {
        clusters.append(contentsOf: value.split(separator: /\s+/).map { String($0) })
      } else {
        settings[String(key)] = String(value)
      }
    }

    for cluster in clusters {
      guard let hosts = settings[cluster]?.split(separator: /\s+/), !hosts.isEmpty else {
        logger.warning("No hosts defined for cluster \(cluster) in \(path)")
        continue
      }
      if (self.clusters[cluster]?.append(contentsOf: hosts.map { String($0) }) == nil) {
        self.clusters[cluster] = hosts.map { String($0) }
      }
    }

    // TODO: update configuration
    // foreach my $key (@config_keys) {
    //   $obj->{$key} = $settings{$key} if exists $settings{$key};
    // }
  }

}
