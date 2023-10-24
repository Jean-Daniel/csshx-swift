//
//  Controller.swift
//  csshx
//
//  Created by Jean-Daniel Dupas on 11/10/2023.
//

import Foundation
import ArgumentParser

extension Csshx {
  struct ControllerCommand: ParsableCommand {

    @Option var windowId: CGWindowID
    @Option var tabIdx: Int

    @Option var launchpid: pid_t = 0

    @OptionGroup(title:"Options")
    var options: Config

    @OptionGroup(title:"SSH Options")
    var sshOptions: SSHOptions

    @OptionGroup(title:"Layout Options")
    var layoutOptions: LayoutOptions

    @Argument(help: "The hosts to connect.")
    var hosts: [String] = []
    
    func run() throws {
      let (settings, hostList) = try Settings.load(hosts, options: options, sshOptions: sshOptions, layoutOptions: layoutOptions)

      // TODO: should it be passed as parameter or send though the master socket instead ?
      var hosts = try hostList.getHosts(limit: settings.pingTest ? 2048 : settings.sessionMax)

      let socket = settings.socket ?? FileManager.default.temporaryDirectory.appendingPathComponent("csshx.\(UUID()).sock").path

      signal(SIGINT, SIG_IGN)
      signal(SIGTSTP, SIG_IGN)
      signal(SIGPIPE, SIG_IGN)

      let tab: Terminal.Tab

      // Used in debug mode to launch the controller manually
      if windowId == 0 {
        var st = stat()
        fstat(STDIN_FILENO, &st)
        tab = try Terminal.Tab(tty: st.st_rdev)
      } else {
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

      // for await _ in DispatchSource.signals(SIGWINCH) {
      //   await ctrl.setNeedsRedraw()
      // }

      // Start listening on
      /*

       my $need_redraw = 1;

       sub new {
           my ($pack) = @_;

           CsshX::Window->init;

           $0 = 'csshX - Master';

           my $sock = $config->sock || die "--sock sockfile is required";
           unlink $sock;
           my $obj = $pack->SUPER::new(Listen => 32, Local => $sock) || die $!;
           chmod 0700, $sock || die "Chmod";

           local $SIG{INT} = 'IGNORE';
           local $SIG{TSTP} = 'IGNORE';
           local $SIG{PIPE}  = "IGNORE";
           local $SIG{WINCH} = sub { $need_redraw=1 };

           $|=1;

           my $stdin = CsshX::Master::Socket::Input->new(*STDIN, "r");
           $stdin->set_master($obj);
           $stdin->set_mode('input');
           $obj->readers->add($stdin);

           kill('USR1', $config->launchpid) || warn "Could not wake up launcher";

           while ((!defined $obj->windowid) || $obj->slave_count || $obj->launcher) {
               $obj->redraw if $need_redraw;
               $obj->title("Master - ".join ", ", grep { defined }
                   map { $_->hostname } CsshX::Master::Socket::Slave->slaves);
               $obj->handle_io();
           }
           unlink $sock;
           warn "Done";
       }
       */
    }

    /*
     sub can_read {
         my ($obj) = @_;
         my $client = $obj->accept("CsshX::Master::Socket::Unknown");
         $client->set_master($obj);
         $obj->readers->add($client);
     }

     sub arrange_windows {
         my ($obj) = @_;
         $obj->move_slaves_to_master_space();
         CsshX::Window::Slave->grid($obj, grep {$_->windowid} $obj->slaves);
         $obj->format_master();
     }
     */
  }
}

