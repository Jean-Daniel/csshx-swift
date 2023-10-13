//
//  Controller.swift
//  csshx
//
//  Created by Jean-Daniel Dupas on 11/10/2023.
//

import Foundation
import ArgumentParser

extension Launcher {
  struct Controller: AsyncParsableCommand {

    @Option var socket: String

    @Option var launchpid: Int

    func run() async throws {
      
      Task {
        for await _ in DispatchSource.signals(SIGWINCH) {
          // TODO: need redraw

        }
      }

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
               #$obj->title("Master - ".$obj->slave_count." connections");
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

     sub send_terminal_input {
         my ($obj, $buffer) = @_;
         if (length $buffer) {
             foreach my $client ($obj->slaves) {
                 $client->send_input($buffer) unless $client->disabled;
             }
         }
     }

     sub set_launcher { *{$_[0]}->{launcher} = $_[1]; }
     sub launcher     { *{$_[0]}->{launcher};         }

     sub set_prompt   { *{$_[0]}->{prompt} = $_[1]; $need_redraw = 1; }
     sub prompt       { *{$_[0]}->{prompt};         }

     sub slaves       { CsshX::Master::Socket::Slave->slaves; }
     sub slave_count  { CsshX::Master::Socket::Slave->slave_count; }

     sub register_slave {
         my ($obj, $slaveid, $hostname, $win_id, $tab_id) = @_;
         eval {
             my $slave = CsshX::Master::Socket::Slave->get_by_slaveid($slaveid) ||
                         CsshX::Master::Socket::Slave->new($slaveid);

             $slave->set_windowid($win_id) if $win_id;
             $slave->set_tabid($tab_id)    if $win_id; # Yes - tab_id can be 0
             $slave->set_hostname($hostname) if $hostname;
             $slave->set_master($obj);

             return $slave;
         };
     }

     sub redraw {
         my ($obj) = @_;
         $obj->clear;
         print $obj->prompt;
         $need_redraw = 0;
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

