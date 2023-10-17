//
//  Launcher.swift
//  csshx
//
//  Created by Jean-Daniel Dupas on 10/10/2023.
//

import ArgumentParser
import Foundation

extension Csshx {
  struct Launcher: AsyncParsableCommand {

    static var configuration = CommandConfiguration(
      commandName: "csshx",
      abstract: "csshX - Cluster SSH tool using Mac OS X Terminal.app",
      discussion: """
                 csshX is a tool to allow simultaneous control of multiple ssh sessions.
                 *host1*, *host2*, etc. are either remote hostnames or remote cluster
                 names. csshX will attempt to create an ssh session to each remote host
                 in separate Terminal.app windows. A *master* window will also be
                 created. All keyboard input in the master will be sent to all the
                 *slave* windows.

                 To specify the username for each host, the hostname can be prepended by
                 *user@*. Similarly, appending *:port* will set the port to ssh to.

                 You can also use hostname ranges, to specify many hosts.
                 """,
    version: "1.0.0")

    @OptionGroup(title:"Options")
    var options: Config

    @OptionGroup(title:"SSH Options")
    var sshOptions: SSHOptions

    @OptionGroup(title:"Layout Options")
    var layoutOptions: LayoutOptions
    
    @Argument(help: "The hosts to connect.")
    var hosts: [String] = []

    mutating func run() async throws {
      logger.info("start launcher")

      let (settings, hostList) = try await Settings.load(hosts, options: options, sshOptions: sshOptions, layoutOptions: layoutOptions)

      // TODO: resolve all hosts
      
      // TODO: ping test support.
      // ICMP mode: Use SimplePing class to check reachability per host.
      // TCP mode: Use Network Framework to perform a TCP connect/close per host/port.



//      if settings.socket.isEmpty {
//        settings.socket = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
//      }

      let controller = try openController(settings: settings)
      if settings.space >= 0 {
        controller.space = settings.space
      }

      // Wait for master to be ready
      do {
        logger.debug("waiting master")
        try await withTimeout(.seconds(10)) {
          await waitFor(signal: SIGUSR1)
        }
      } catch is TimedOutError {
        logger.debug("master starting timeout")
        print("No master")

        Foundation.exit(1)
      } catch {
        logger.debug("master starting failure \(error)")
        Self.exit(withError: error)
      }

//      var hosts = hosts
//      if (settings.sorthosts) {
//        hosts.sort()
//      }
//
//      if (settings.interleave > 1) {
//        var cur = 0
//        var wrap = 0
//        var new_hosts = [String]()
//        for _ in 0..<hosts.count {
//          new_hosts.append(hosts[cur])
//          cur += settings.interleave
//          if (cur >= hosts.count) {
//            wrap += 1
//            cur = wrap
//          }
//        }
//        hosts = new_hosts
//      }
//
//      var hostId = 0
//      var greeting = "launcher\n\(controller.windowId),\(controller.tabIdx)\n"
//
//      for host in hosts {
//        // my $rem_command = $host->command || $config->remote_command || '';
//        hostId += 1
//
//        let hostTab = try openTab(host: host, id: hostId, settings: settings)
//        if (settings.space >= 0) {
//          hostTab.space = settings.space
//        }
//
////        if let set = settings.hostSettingsSet {
////          $slave->set_settings_set($config->slave_settings_set)
////        }
//
//        greeting += "\(hostId) \(hostTab.windowId),\(hostTab.tabIdx)\n";
//      }
//      greeting += "done\n"
//
//      // Sending greeting and tear down
//      guard let greetingBytes = greeting.data(using: .utf8) else {
//        throw POSIXError(.EINVAL)
//      }
//
//      let client = try await IOClient.connect(socket: settings.socket)
//
//      // tell the master the laucher is done
//      try await client.write(data: greetingBytes)
//
//      // and exit
//      await client.close()
    }

    private func openController(settings cfg: Settings) throws -> Terminal.Tab {
      let csshx = URL(filePath: CommandLine.arguments[0]).standardizedFileURL
      let args = [ "echo", "hello", "world" ]
//      let args: [String] = [
//        csshx.path, "--", "controller",
//        "--launchpid", "\(getpid())",
//        "--socket", "\(cfg.socket)",
//      ]

      //    if let socket = cfg.socket {
      //      args.append("--sock")
      //      args.append(socket)
      //    }
      //    if let login = cfg.login {
      //      args.append("--login")
      //      args.append(login)
      //    }
      //    for c in cfg.configs {
      //      args.append("--config")
      //      args.append(c.absoluteURL.path)
      //    }

      let tab = try Terminal.Tab.open()

      // Set profile first.
      if let profile = cfg.controllerWindowProfile {
        if (!tab.setProfile(profile)) {
          // TODO: print warning ?
        }
      }

      try tab.run(args: args)
      return tab
    }

//    private func openTab(host: String, id hostId: Int, settings cfg: Settings) throws -> Terminal.Tab {
//      let csshx = URL(filePath: CommandLine.arguments[0]).standardizedFileURL
//
//      let args: [String] = [
//        csshx.path, "--", "host",
//        "--socket", "\(cfg.socket)",
//        "--slaveid", "\(hostId)",
//        "--slavehost", "\(host)",
//      ]
////        $script, '--slave', '--sock', $sock, '--slavehost', $slavehost,
////        '--debug', $config->debug, '--ssh', $config->ssh,
////        '--ssh_args', $config->ssh_args, '--remote_command', $rem_command,
////        '--slaveid', $slave_id, $login  ? ( '--login',    $login  ) :(),
////        (map { ('--config', $_) } @config),
////      ) or next;
//
//      //    if let socket = cfg.socket {
//      //      args.append("--sock")
//      //      args.append(socket)
//      //    }
//      //    if let login = cfg.login {
//      //      args.append("--login")
//      //      args.append(login)
//      //    }
//      //    for c in cfg.configs {
//      //      args.append("--config")
//      //      args.append(c.absoluteURL.path)
//      //    }
//
//      let tab = try Terminal.Tab.open()
//      try tab.run(args: args)
//      return tab
//    }
  }
}
