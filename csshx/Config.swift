//
//  Config.swift
//  csshx
//
//  Created by Jean-Daniel Dupas on 06/10/2023.
//

import ArgumentParser
import Foundation
import RegexBuilder

struct LayoutOptions: ParsableArguments {

  @Option(help: ArgumentHelp("Sets the screen(s) on which to display the terminals, if you have multiple monitors.",
                             discussion: """
                              If the argument is passed a number, that screen will be used.

                              If a range (of the format 1-2) is passed, a rectangle that fits within those displays will be chosen. Particularly odd arrangements of windows, such as "L" shapes will probably not work.

                              Screens are numbered from 1.
                              """))
  var screen: Int = 0

  @Option(help: "Sets the space (if Spaces is enabled) on which to display the terminals. Defaults to current space")
  var space: Int = 0

  @Option(name: [.customShort("x"), .customLong("tile_x"), .customLong("columns")],
          help: "The number of columns to use when tiling windows.")
  var columns: Int = 0

  @Option(name: [.customShort("y"), .customLong("tile_y"), .customLong("rows")],
          help: "The number of rows to use when tiling windows. Ignored if tile_x is specified..")
  var rows: Int = 0

  @Flag(help: "Sort the host windows, by hostname, before opening them.")
  var sortHosts = false

  @Option(name: [.short, .long],
          help: ArgumentHelp("Interleave the hosts that were passed in. Useful when multiple clusters are specified.",
                            discussion: """
                             For instance, if clusterA and clusterB each have 3 hosts, running csshX -tile_x 2 -interleave 3 clusterA clusterB

                             will display as clusterA1 clusterB1 clusterA2 clusterB2 clusterA3 clusterB3

                             as opposed to the default clusterA1 clusterA2 clusterA3 clusterB1 clusterB2 clusterB3
                             """))
  var interleave: Int = 0

  @Option var controllerWindowProfile: String?
  @Option var hostWindowProfile: String?
}

struct SSHOptions: ParsableArguments {

  @Option(name: [.short, .long],
          help: "Remote user to authenticate as for all hosts. This is overridden by *user@*.")
  var login: String?

  @Option(help: ArgumentHelp("Change the command that is run.",
                             discussion: "May be useful if you use an alternative ssh binary or some wrapper script to connect to hosts."))
  var ssh: String = "ssh"

  @Option(help: ArgumentHelp("Sets a list of arguments to pass to the ssh binary when run.",
                             discussion: "If there is more than one, they must be quoted or escaped to prevent csshX from interpreting them."))
  var sshArgs: String?

  @Option(help: ArgumentHelp("Sets the command to run on the remote system after authenticating.",
                             discussion: """
                              If the command contains spaces, it should be quoted or escaped.

                              To run different commands on different hosts, see the --hosts
                              option.
                              """))
  var remoteCommand: String?

  @Option(name: .customLong("hosts"),
          parsing: .singleValue,
          help: ArgumentHelp("Load a file containing a list of hostnames to connect to and, optionally, commands to run on each host.",
                            discussion: """
                             A single dash - can be used to read hosts data from standard input, for example, through a pipe.

                             See HOSTS for the file format.
                             """), completion: .file())
  var hostFiles: [String] = []

  @Option(help: ArgumentHelp("Set the maximum number of ssh Terminal sessions that can be opened during a single csshX session.",
                            discussion: """
                                 By default csshX will not open more than 256 sessions. You must set this to something really high to get around that. (default: 256)

                                 Note that you will probably run out of Pseudo-TTYs before reaching 256 terminal windows.
                                 """))
  var sessionMax: Int = 256

  @Flag(name: [.long, .customLong("ping")],
        help: ArgumentHelp("Make csshX ping each host/port before opening ssh connections",
                          discussion: """
                          To avoid opening connections to machines that are down, or not running sshd, this option will make csshX ping each host/port that is specified. This uses the Net::Ping module to perform a simple syn/ack check.

                          Use of this option is highly recommended when subnet ranges are used.
                          """))
  var pingTest = false

  @Option(help: ArgumentHelp("This sets the timeout used when the 'ping_test' feature is enabled.",
                            discussion: """
                            This timeout applies once per destination port used. Also, if the number of hosts to ping is greater than the number of filehandles available pings will be batched, and the timeout will apply once per batch. You can set 'ulimit -n' to improve this performance.

                            The value is in seconds. (default: 2)
                            """))
  var pingTimeout: Int = 2
}

struct Config: ParsableArguments {

  @Option(name: [.short, .customLong("config")],
          parsing: .singleValue,
          help: "Alternative config file to use",
          completion: .file())
  var configFile: [String] = []

  @Option(name: [.customLong("sock")],
          help: ArgumentHelp("Sets the Unix domain socket filename to be used for interprocess communication.",
                             discussion: "This may be set by the user in the launcher session, possibly for security reasons."),
          completion: .file()) var socket: String?

  @Flag(help: ArgumentHelp("Enable debugging behaviors.",
                          discussion: """
                          Enables backtrace on fatal errors, and keeps terminal windows open after terminating (so you can see any errors)..
                          """))
  var debug: Bool = false
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
