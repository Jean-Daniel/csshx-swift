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

//  @Option(name: .customLong("config")) var configs: [String] = []

  @Option(name: [.short, .long]) var login: String?

//  @Option(name: [.customLong("sock")]) var socket: String?
//
//  @Option(name: [.short, .customLong("tile_x")]) var x: Int = 0
//  @Option(name: [.short, .customLong("tile_y")]) var y: Int = 0
//
//  @Flag(name: [.long, .customLong("ping")]) var pingTest = false
//  @Option var pingTimeout: Int = 2
//
//  @Option var screen: Int = 0
//  @Option var space: Int = 0
//  @Option var sshArgs: String?
//  @Option var debug: Int = 0
//
//  @Option var sessionMax: Int = 256
//  @Flag var version = false
//
//  @Option var ssh: String = "ssh"
//  @Option var hosts: [String] = []
//
//  @Option var remoteCommand: String?
//  @Option var masterSettingsSet: String?
//  @Option var slaveSettingsSet: String?
//
//  @Option(name: [.short, .long]) var interleave: Int = 0
//  @Flag var sortHosts = false

}

struct ClusterList {

  private var clusters = [String:[String]]()

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

  mutating func load(contentsOf file: URL) async throws {
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
        add(hosts.map { String($0) }, to: cluster)
      }
    } catch CocoaError.fileNoSuchFile {
      logger.debug("\(file) does not exists. Skipping it.")
    } catch {
      print ("Error: \(error)")
    }
  }
}
