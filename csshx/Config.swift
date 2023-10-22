//
//  Config.swift
//  csshx
//
//  Created by Jean-Daniel Dupas on 06/10/2023.
//

import ArgumentParser

import System
import Foundation
import RegexBuilder

struct LayoutOptions: ParsableArguments {

  @Option(help: ArgumentHelp(discussion: """
                             Sets the screen(s) on which to display the terminals, if you have
                             multiple monitors. If the argument is passed a number, that screen
                             will be used.

                             If a range (of the format 1-2) is passed, a rectangle that fits
                             within those displays will be chosen. Particularly odd arrangements
                             of windows, such as "L" shapes will probably not work.

                             Screens are numbered from 1.
                             """))
  var screen: Int?

  @Option(help: "Sets the space (if Spaces is enabled) on which to display the terminals. Defaults to current space")
  var space: Int?

  @Option(name: [.customShort("x"), .customLong("columns"), .customLong("tile_x")],
          help: "The number of columns to use when tiling windows.")
  var columns: Int?

  @Option(name: [.customShort("y"), .customLong("rows"), .customLong("tile_y")],
          help: "The number of rows to use when tiling windows. Ignored if tile_x is specified..")
  var rows: Int?

  @Flag(help: "Sort the host windows, by hostname, before opening them.")
  var sortHosts = false

  @Option(name: [.short, .long],
          help: ArgumentHelp(discussion: """
                             Interleave the hosts that were passed in. Useful when
                             multiple clusters are specified.

                             For instance, if clusterA and clusterB each have 3 hosts, running
                             csshX -tile_x 2 -interleave 3 clusterA clusterB

                             will display as clusterA1 clusterB1 clusterA2 clusterB2 clusterA3
                             clusterB3

                             as opposed to the default clusterA1 clusterA2 clusterA3 clusterB1
                             clusterB2 clusterB3
                             """))
  var interleave: Int?

  @Option(name: [.customLong("controller_window_profile"), .customLong("master_settings_set"), .customLong("mss")],
          help: "Name of the 'Terminal' Profile that should be use for the controller window.")
  var controllerWindowProfile: String?

  @Option(name: [.customLong("host_window_profile"), .customLong("slave_settings_set"), .customLong("sss")],
          help: "Name of the 'Terminal' Profile that should be use for the host windows.")
  var hostWindowProfile: String?

  func override(_ settings: inout Settings) {
    if let screen { settings.screen = screen }
    if let space { settings.space = Int32(space) }
    if let columns { settings.columns = columns }
    if let rows { settings.rows = rows }
    settings.sortHosts = settings.sortHosts || sortHosts
    if let interleave { settings.interleave = interleave }
    if let controllerWindowProfile { settings.controllerWindowProfile = controllerWindowProfile }
    if let hostWindowProfile { settings.hostWindowProfile = hostWindowProfile }
  }
}

struct SSHOptions: ParsableArguments {

  @Option(name: [.short, .long],
          help: "Remote user to authenticate as for all hosts. This is overridden by *user@*.")
  var login: String?

  @Option(help: ArgumentHelp(discussion: """
                             Change the command that is run. May be useful if you use an
                             alternative ssh binary or some wrapper script to connect to hosts.
                             """))
  var ssh: String?

  @Option(help: ArgumentHelp(discussion: """
                             Sets a list of arguments to pass to the ssh binary when run. If
                             there is more than one, they must be quoted or escaped to prevent
                             csshX from interpreting them.
                             """))
  var sshArgs: String?

  @Option(help: ArgumentHelp(discussion: """
                             Sets the command to run on the remote system after authenticating.
                             If the command contains spaces, it should be quoted or escaped.

                             To run different commands on different hosts, see the --hosts
                             option.
                             """))
  var remoteCommand: String?

  @Option(help: ArgumentHelp(discussion: """
                             Set the maximum number of ssh Terminal sessions that can be opened
                             during a single csshX session. By default csshX will not open more
                             than 256 sessions. You must set this to something really high to get
                             around that. (default: 256)

                             Note that you will probably run out of Pseudo-TTYs before reaching
                             256 terminal windows.
                             """))
  var sessionMax: Int? = nil

  @Flag(name: [.long, .customLong("ping")],
        help: ArgumentHelp("Make csshX ping each host/port before opening ssh connections",
                           discussion: """
                        To avoid opening connections to machines that are down, or not running
                        sshd, this option will make csshX ping each host/port that is specified.
                        This uses the Net::Ping module to perform a simple syn/ack check.

                        Use of this option is highly recommended when subnet ranges are used.
                        """))
  var pingTest = false

  @Option(help: ArgumentHelp(discussion: """
                             This sets the timeout used when the "ping_test" feature is enabled.

                             Due to the implementation of Net::Ping syn/ack checks, this timeout
                             applies once per destination port used. Also, if the number of hosts
                             to ping is greater than the number of filehandles available pings
                             will be batched, and the timeout will apply once per batch. You can
                             set 'ulimit -n' to improve this performance.

                             The value is in seconds.
                             """))
  var pingTimeout: Int? = nil

  func override(_ settings: inout Settings) {
    if let login { settings.login = login }
    if let ssh { settings.ssh = ssh }
    if let sshArgs { settings.sshArgs = sshArgs }
    if let remoteCommand { settings.remoteCommand = remoteCommand }
    if let sessionMax { settings.sessionMax = sessionMax }
    settings.pingTest = settings.pingTest || pingTest
    if let pingTimeout { settings.pingTimeout = pingTimeout }
  }
}

struct Config: ParsableArguments {

  @Option(name: [.short, .customLong("config")],
          parsing: .singleValue,
          help: "Alternative config file to use",
          completion: .file())
  var configFiles: [String] = []

  @Option(name: .customLong("hosts"),
          parsing: .singleValue,
          help: ArgumentHelp(discussion: """
                            Load a file containing a list of hostnames to connect to and,
                            optionally, commands to run on each host. A single dash - can be
                            used to read hosts data from standard input, for example, through a
                            pipe.

                            See HOSTS for the file format.
                            """), completion: .file())
  var hostFiles: [String] = []

  @Option(name: [.customLong("sock"), .customLong("socket")],
          help: ArgumentHelp(discussion: """
                            Sets the Unix domain socket filename to be used for interprocess
                            communication. This may be set by the user in the launcher session,
                            possibly for security reasons.
                            """),
          completion: .file())
  var socket: String?

  @Flag(help: ArgumentHelp("Enable debugging behaviors.",
                           discussion: """
                         Enables backtrace on fatal errors, and keeps terminal windows open after terminating (so you can see any errors).
                         """))
  var debug: Bool = false

  func override(_ settings: inout Settings) {
    if let socket { settings.socket = socket }
    settings.debug = settings.debug || debug
  }
}
