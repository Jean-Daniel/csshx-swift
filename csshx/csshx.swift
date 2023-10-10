//
//  csshx.swift
//  csshx
//
//  Created by Jean-Daniel Dupas on 03/10/2023.
//

import ArgumentParser
import Foundation
import OSLog

let logger = Logger(subsystem: "com.xenonium.csshx", category: "main")

@main
struct CsshX: AsyncParsableCommand {
  static var configuration: CommandConfiguration = CommandConfiguration(
    subcommands: [Launcher.self, Primary.self, Host.self],
    defaultSubcommand: Launcher.self
  )
}


extension CsshX {
  struct Launcher: AsyncParsableCommand {

    @OptionGroup
    var config: Config

    @Argument(help: "The host or cluster to connect.")
    var clusters: [String] = []

    mutating func run() async throws {
      logger.info("start launcher")

      try await config.load()
      /*
       # Load modules
       CsshX::Window->init;

       # Call, just to make sure screen number is sane
       CsshX::Window->screen_bounds;
       */

      /*
       my @hosts  = $config->all_hosts;
       my $sock   = $config->sock || tmpnam();
       my $login  = $config->login || '';
       my @config = @{$config->config};

       my $master = CsshX::Window::Master->open_window(
       $script, '--master', '--sock', $sock, '--launchpid', $$,
       '--screen', $config->screen, '--debug', $config->debug,
       '--tile_y', $config->tile_y, '--tile_x', $config->tile_x,
       $login  ? ( '--login',    $login  ) :(),
       (map { ('--config', $_) } @config),
       ) or die "Master window failed to open";

       if ($config->space)
       $master->set_space($config->space);

       if ($config->master_settings_set)
       $master->set_settings_set($config->master_settings_set) ;

       */

      // Wait for master to be ready
      do {
        logger.debug("waiting master")
        try await withTimeout(.seconds(10)) {
          await waitForSignal(SIGUSR1)
        }
      } catch is TimedOutError {
        logger.debug("master starting timeout")
        print("No master")
        Foundation.exit(1)
      } catch {
        logger.debug("master starting failure \(error)")
        Self.exit(withError: error)
      }


      /*
       if ($config->sorthosts) {
       @hosts = sort { $a->name cmp $b->name } @hosts;
       }

       if ($config->interleave > 1) {
       my $wrap = 0;
       my $cur = 0;
       my @new_hosts;
       foreach (@hosts) {
       push @new_hosts, $hosts[$cur];
       $cur += $config->interleave;
       if ($cur > $#hosts) {
       $cur = ++$wrap;
       }
       }
       @hosts = @new_hosts;
       }

       my $slave_id = 0;
       foreach my $host (@hosts) {
       my $slavehost = $host->name;
       my $rem_command = $host->command || $config->remote_command || '';
       $slave_id++;
       my $slave = CsshX::Window::Slave->open_window(
       $script, '--slave', '--sock', $sock, '--slavehost', $slavehost,
       '--debug', $config->debug, '--ssh', $config->ssh,
       '--ssh_args', $config->ssh_args, '--remote_command', $rem_command,
       '--slaveid', $slave_id, $login  ? ( '--login',    $login  ) :(),
       (map { ('--config', $_) } @config),
       ) or next;

       my $greeting = "launcher\n";
       $greeting .= $master->uid."\n";
       $greeting .= "$slave_id ".$slave->uid."\n";
       $slave->set_space($config->space) if $config->space;
       $slave->set_settings_set($config->slave_settings_set)
       if $config->slave_settings_set;
       }
       $greeting .= "done\n";

       my $obj = $pack->SUPER::new($sock) || die $!;

       $obj->set_write_buffer($greeting);
       $obj->writers->add($obj);

       $obj->handle_io() while $obj->readers->handles;
       */
    }
  }
}

extension CsshX {
  struct Primary: AsyncParsableCommand {

    @Option var launchpid: Int

    func run() async throws {
      
    }

  }
}

extension CsshX {
  struct Host: AsyncParsableCommand {

    @Option var slavehost: String
    @Option var slaveid: Int

    func run() async throws {

    }
  }
}

// MARK: - Helper Functions
func waitForSignal(_ signal: Int32) async {
  let sigusr1 = DispatchSource.makeSignalSource(signal: signal, queue: DispatchQueue.main)
  // Add Task Cancellation handler to cancel the source when the Task is cancelled.
  await withTaskCancellationHandler {
    // If task already cancelled, the cancel handler may have already been invoked
    guard !sigusr1.isCancelled else {
      // A DispatchSource must be resume at least once, even if cancelled
      sigusr1.resume()
      return
    }

    // Waiting Dispatch Source first callback.
    await withCheckedContinuation { contination in
      sigusr1.setEventHandler {
        // let the cancellation handler resume the continuation
        logger.debug("signal \(signal) received")
        sigusr1.cancel()
      }

      sigusr1.setCancelHandler {
        contination.resume()
      }
      // Start the dispatch source.
      logger.debug("waiting for signal: \(signal)")
      sigusr1.resume()
    }
  } onCancel: {
    logger.debug("cancelling signal handler for signal \(signal)")
    sigusr1.cancel()
  }
}

struct PrimaryWindow {


  static func open(config cfg: Config) {
    let script = CommandLine.arguments[0]

    var args: [String] = [
      script, "master",
      "--launchpid", "\(getpid())",
      "--screen", "\(cfg.screen)",
      "--debug", "\(cfg.debug)",
      "--tile_x", "\(cfg.x)",
      "--tile_y", "\(cfg.y)",
    ]
    if let socket = cfg.socket {
      args.append("--sock")
      args.append(socket)
    }
    if let login = cfg.login {
      args.append("--login")
      args.append(login)
    }
    for c in cfg.configs {
      args.append("--config")
      args.append(c)
    }

  }
}

