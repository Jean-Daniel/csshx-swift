//
//  Launcher.swift
//  csshx
//
//  Created by Jean-Daniel Dupas.
//

import ArgumentParser
import Foundation

public struct Launcher: ParsableCommand, Sendable {

  public static let configuration = CommandConfiguration(
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
  
  public init() {}
  
  public mutating func run() throws {
    logger.info("start launcher")
    
    let (settings, hostList) = try Settings.load(hosts, options: options, sshOptions: sshOptions, layoutOptions: layoutOptions)
    
    // resolve host list to make sure it is valid, or failing before launching the master.
    let _ = try hostList.getHosts(limit: settings.pingTest ? 2048 : settings.sessionMax)
    
    if (settings.pingTest) {
      // TODO: ping test support.
      // ICMP mode: Use SimplePing class to check reachability per host.
      // TCP mode: Use Network Framework to perform a TCP connect/close per host/port.
    }
    
    let tab = try Terminal.Tab.open()
    
    // Set profile first.
    if let profile = settings.controllerWindowProfile {
      if (!tab.setProfile(profile)) {
        // TODO: print warning ?
      }
    }
    
    // Install signal handler before stating master
    
    // Note: DispatchSourceSignal is based on kevent, and is independent of signal()/sigaction().
    // The SIGUSR1 must be disabled in 'signal' to avoid process death when receiving it.
    Darwin.signal(SIGUSR1, SIG_IGN)
    waitFor(signal: SIGUSR1, timeout: .seconds(10), queue: DispatchQueue.main) { timeout in
      if (timeout) {
        logger.debug("master starting timeout")
        print("No master")
        Foundation.exit(1)
      } else {
        Foundation.exit(0)
      }
      Foundation.exit(1)
    }
    
    let csshx = CommandLine.executableURL()
    var args: [String] = [
      csshx.path, "--", "controller",
      "--launchpid", "\(getpid())",
      "--window-id", "\(tab.windowId)",
      "--tab-idx", "\(tab.tabIdx)"
    ]
    // Do not exec in debug mode
    if settings.debug {
      args.remove(at: 2)
    }
    
    // forward all arguments
    args.append(contentsOf: CommandLine.arguments.dropFirst())
    
    try tab.run(args: args, clear: true, exec: !settings.debug)
    
    // Wait for master to be ready
    logger.debug("waiting master")
    
    // Once master is ready, we are done.
    // TODO: if implementing ping test, maybe it should be done by the launcher
    //   and result forwarded to the master though the master socket.
    dispatchMain()
  }
}
