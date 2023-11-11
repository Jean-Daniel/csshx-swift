//
//  ControllerCommand.swift
//  csshx
//
//  Created by Jean-Daniel Dupas.
//

import Cocoa
import ArgumentParser

// import Bridge
public struct ControllerCommand: ParsableCommand {

  @Option var windowId: CGWindowID?
  @Option var tabIdx: Int = 1
  
  @Option var launchpid: pid_t = 0
  
  @OptionGroup(title:"Options")
  var options: Config
  
  @OptionGroup(title:"SSH Options")
  var sshOptions: SSHOptions
  
  @OptionGroup(title:"Layout Options")
  var layoutOptions: LayoutOptions
  
  @Argument(help: "The hosts to connect.")
  var hosts: [String] = []
  
  public init() {}
  
  public func run() throws {
    let (settings, hostList) = try Settings.load(hosts, options: options, sshOptions: sshOptions, layoutOptions: layoutOptions)
    
    // TODO: should it be passed as parameter or send though the master socket instead ?
    var hosts = try hostList.getHosts(limit: settings.pingTest ? 2048 : settings.sessionMax)
    
    let socket = settings.socket ?? FileManager.default.temporaryDirectory.appendingPathComponent("csshx.\(UUID()).sock").path
    
    signal(SIGINT, SIG_IGN)
    signal(SIGTSTP, SIG_IGN)
    signal(SIGPIPE, SIG_IGN)
    
    var tab: Terminal.Tab? = nil
    
    // Used in debug mode to launch the controller manually
    if windowId == 0 {
      var st = stat()
      fstat(STDIN_FILENO, &st)
      tab = try Terminal.Tab(tty: st.st_rdev)
    } else if let windowId {
      tab = try Terminal.Tab(window: windowId, tab: tabIdx)
    }
    
    let ctrl = try Controller(tab: tab, socket: socket, settings: settings)
    // Start listening socket
    try ctrl.listen()
    
    // Start UI
    try ctrl.runInputLoop()
    
    // Signal the launcher that the socket is ready
    if (launchpid > 0 && kill(launchpid, SIGUSR1) < 0) {
      let err = errno
      logger.warning("launcher signaling failed: \(err)")
    }
    
    // Prepare host list
    if (settings.sortHosts) {
      hosts.sort { $0.hostname < $1.hostname }
    }
    
    if (settings.interleave > 1) {
      var cur = 0
      var wrap = 0
      var new_hosts = [Target]()
      for _ in 0..<hosts.count {
        new_hosts.append(hosts[cur])
        cur += settings.interleave
        if (cur >= hosts.count) {
          wrap += 1
          cur = wrap
        }
      }
      hosts = new_hosts
    }
    
    // Starting all host in //
    let group = DispatchGroup()
    for host in hosts {
      group.enter()
      
      do {
        try ctrl.add(host: host) { error in
          group.leave()
        }
      } catch {
        logger.error("error while starting host \(host.hostname): \(error)")
        group.leave()
      }
    }
    
    group.notify(queue: .main) {
      logger.info("All hosts started -> Notify controller")
      do {
        try ctrl.ready()
      } catch {
        logger.error("ready failed with error: \(error)")
        ctrl.close()
      }
    }
    
    // required to get display change notifications
    NSApplication.shared.run()
  }
}
