//
//  ControllerUI.swift
//  csshx
//
//  Created by Jean-Daniel Dupas on 18/10/2023.
//

import Foundation
import RegexBuilder

private let kb = "\u{001b}[4m\u{001b}[1m"  // Bold Underline
private let kk = "\u{001b}[0m"              // Reset

class HostWindow: Equatable {

  let tab: Terminal.Tab
  let host: Target
  let tty: dev_t

  // Terminal Tab + Socket Connection
  var whenDone: ((Error?) -> Void)? = nil
  var connection: DispatchIO? = nil

  var enabled: Bool = true

  init(tab: Terminal.Tab, host: Target, tty: dev_t) {
    self.tab = tab
    self.host = host
    self.tty = tty
  }

  func terminate() {
    connection?.close(flags: .stop)
    connection = nil
    enabled = false
    // Closing window in case the profile does not close window automatically
    // tab.close()
  }

  static func == (lhs: HostWindow, rhs: HostWindow) -> Bool {
    return lhs.host == rhs.host && lhs.tab == rhs.tab
  }
}

// MARK: -
class Controller {

  let tab: Terminal.Tab
  let socket: String
  let settings: Settings

  private var term: termios? = nil

  fileprivate var hosts: [HostWindow] = []

  private var inputMode: InputMode = .starting

  private var buffer: [UInt8] = []
  private var stdin: DispatchIO? = nil

  fileprivate var listener: IOListener? = nil

  init(tab: Terminal.Tab, socket: String, settings: Settings) throws {
    self.tab = tab
    self.socket = socket
    self.settings = settings
    self.buffer.reserveCapacity(256)

    layoutControllerWindow()
  }

  func close() {
    stdin?.close(flags: .stop)
    listener?.close()
    hosts.forEach { $0.terminate() }
  }

  func ready() throws {
    if inputMode == .starting {
      // TODO: layout hosts window
      try setInputMode(.input)
    }
  }

  func send(bytes: some ContiguousBytes) {
    let data = bytes.withUnsafeBytes(DispatchData.init(bytes:))
    for host in hosts {
      // Skip disabled hosts, and not connected host
      guard host.enabled, let connection = host.connection else { continue }

      connection.write(data) { [self] error in
        // on error -> remove host from the host list
        if error != nil {
          logger.warning("error while forwarding data to host: \(host.host.hostname)")
          terminate(host: host)
        }
      }
    }
  }

  private func setRawInputMode(_ value: Bool) throws {
    if term == nil, value {
      // saving current tty state, and switch to raw mode
      self.term = try stty.raw()
    } else if let term, !value {
      // restoring tty state
      try stty.set(attr: term)
      self.term = nil
    }
  }

  func prompt() {
    guard stdin != nil else { return }

    stty.clear()
    print(inputMode.prompt(self))
  }

  func setInputMode(_ mode: InputMode) throws {
    guard mode.id != inputMode.id else { return }

    logger.info("Switching input mode")
    inputMode = mode

    try setRawInputMode(mode.raw)
    try mode.onEnable(self)
    prompt()
  }

  func runInputLoop() throws {
    guard stdin == nil else {
      return
    }

    let input = DispatchIO(type: .stream,
                           fileDescriptor: STDIN_FILENO,
                           queue: .main, cleanupHandler: { [self] error in
      do {
        try setRawInputMode(false)
      } catch {}
    })
    // disable buffering
    input.setLimit(lowWater: 1)
    stdin = input

    // Initialize input mode
    try setRawInputMode(inputMode.raw)
    try inputMode.onEnable(self)
    prompt()

    input.read { [self] bytes in
      onBytesAvailable(bytes)
    } whenDone: { [self] error in
      // unreachable, as stdin should never be done.
      if let error {
        logger.warning("stdin done with error: \(error)")
        close()
      }
      // we are done
      Foundation.exit(0)
    }
  }

  private func onBytesAvailable(_ bytes: DispatchData) {
    buffer.append(contentsOf: bytes)

    // if mode changed and buffer is not empty -> reparse
    while (!buffer.isEmpty) {
      let id = inputMode.id
      do {
        try inputMode.parseInput(self, &buffer)
      } catch {
        logger.error("error while processing input: \(error)")
        close()
        return
      }

      // No mode change, exit the loop
      if (id != inputMode.id) { break }
    }
  }

  private func layoutControllerWindow() {
    // my $mh = $config->master_height;
    // my ($x,$y,$w,$h) = @{$obj->screen_bounds};

    if let color = settings.controllerBackground {
      tab.setBackgroundColor(color: color)
    }

    if let color = settings.controllerForeground {
      tab.setTextColor(color: color)
    }

//    let screen: CGRect = CGRect.zero
//
//    tab.window.miniaturized = false
//    tab.window.bounds = CGRect(origin: screen.origin, size: CGSize(width: screen.width, height: settings.controllerHeight))

//    // Now check the height of the terminal window in case it's larger than
//    // expected, if so, move it off the bottom of the screen if possible
//    let real = tab.window.size
//    if (real.y > settings.controllerHeight) {
//      tab.window.origin = CGPoint(x: screen.origin.x, y: screen.origin.y - (real.y - settings.controllerHeight))
//    }
//    tab.window.frontmost = true
  }
}

// MARK: - Controller Socket
extension Controller {

  private func getPid(socket: Int32) -> pid_t {
    var pid: pid_t = 0
    var pid_size = socklen_t(MemoryLayout.size(ofValue: pid))
    guard getsockopt(socket, SOL_LOCAL, LOCAL_PEERPID, &pid, &pid_size) == 0 else {
      logger.warning("failed to retreive socket pid: \(errno)")
      return 0
    }
    return pid
  }

  func listen() throws {
    guard listener == nil else {
      throw POSIXError(.EBUSY)
    }

    logger.info("start listening on \(self.socket)")
    let srv = try IOListener.listen(socket: socket)
    listener = srv

    srv.startWaiting { [self] result in
      switch (result) {
        case .success(let fd):
          let pid = getPid(socket: fd)
          logger.info("did open connection from pid \(pid)")
          let tty = Bridge.getProcessTTY(pid)
          guard tty > 0 else {
            logger.warning("cannot get connected process tty. Rejecting the connection")
            Darwin.close(fd)
            return
          }
          logger.info("[\(pid)] connection tty: \(tty)")
          didOpen(socket: fd, tty: tty)
        case .failure(let error):
          logger.error("server socket error: \(error)")
          close()
      }
    }
  }

  private func didOpen(socket: Int32, tty: dev_t) {
    logger.info("on open connection: \(tty)")

    // lookup matching host window and attach the connection
    guard let host = hosts.first(where: { $0.tty == tty }) else {
      logger.warning("did not find matching host window for tty: \(tty)")
      Darwin.close(socket)
      return
    }
    host.connection = DispatchIO(type: .stream,
                                 fileDescriptor: socket,
                                 queue: DispatchQueue.main,
                                 cleanupHandler: { error in Darwin.close(socket) })

    if let done = host.whenDone {
      host.whenDone = nil
      done(nil)
    }

    // Start a monitoring task. An host is not supposed to write in the connection,
    // but it help us detect when the connection is closed.
    host.connection?.read {data in
      logger.warning("discarding unexpected input: \(data.count) bytes")
    } whenDone: {  [self] error in
      logger.warning("[\(host.host.hostname)] connection lost")
      terminate(host: host)
    }
  }
}

// MARK: - Hosts Management
extension Controller {

  func add(host target: Target, whenDone done: @escaping (Error?) -> Void) throws {
    let tab = try Terminal.Tab.open()
    if let profile = settings.hostWindowProfile {
      if (!tab.setProfile(profile)) {
        // TODO: print warning ?
      }
    }
    let tty = tab.tty()
    guard tty > 0 else {
      throw ScriptingBridgeError()
    }
    logger.info("[\(target.hostname)] opening window: \(tab.windowId)/\(tab.tabIdx) (tty: \(tty))")

    let host = HostWindow(tab: tab, host: target, tty: tty)
    host.whenDone = done
    hosts.append(host)

    let csshx = URL(filePath: CommandLine.arguments[0]).standardizedFileURL
    var args = [
      csshx.path, "--", "host",
      "--ssh", settings.ssh,
      "--socket", socket,
      "--hostname", target.hostname,
    ]
    if let user = target.user {
      args.append("--login")
      args.append(user)
    }
    if let port = target.port {
      args.append("--port")
      args.append(String(port))
    }
    // TODO: ssh args and remote command

    do {
      try tab.run(args: args, clear: true, exec: !settings.debug)
    } catch {
      // Something went wrong while starting -> abort now
      terminate(host: host)
      done(error)
      return
    }
    logger.info("did start csshx \(target.hostname)")

    // Simple timeout scheme. Instead of scheduling a DispatchSourceTimer, and having to manage it
    // unconditonally schedule a block after delay, and test if the op is done when this block is executed.
    DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(5)) { [weak self] in
      // if operation not done yet -> cancel it.
      if let self, let done = host.whenDone {
        terminate(host: host)
        done(POSIXError(.ETIMEDOUT))
      }
    }
  }

  func terminate(host: HostWindow) {
    guard let idx = hosts.firstIndex(of: host) else {
      return
    }
    hosts.remove(at: idx).terminate()
    if (hosts.isEmpty) {
      // Terminate input loop if is running
      close()
    }
  }

}


// MARK: - Input Modes
struct InputMode: Equatable {
  // Using autogenerated id to detect input mode change
  let id: UUID = UUID.init()
  let raw: Bool

  let prompt: (Controller) -> String
  let onEnable: (Controller) throws -> Void
  let parseInput: (Controller, inout [UInt8]) throws -> Void

  init(raw: Bool = true, 
       prompt: @escaping (Controller) -> String,
       onEnable: @escaping (Controller) -> Void,
       parseInput: @escaping (Controller, inout [UInt8]) throws -> Void) {
    self.raw = raw
    self.prompt = prompt
    self.onEnable = onEnable
    self.parseInput = parseInput
  }

  static func == (lhs: InputMode, rhs: InputMode) -> Bool {
    lhs.id == rhs.id
  }
}

// MARK: -
let csiCursorCode = Regex {
  "\u{001b}["
  Capture("A"..."D")
}

extension InputMode {
  static let starting: InputMode = InputMode { ctrl in
    "Starting hosts: \(ctrl.hosts.count { $0.connection != nil } )/\(ctrl.hosts.count)…"
  } onEnable: { ctrl in
    // noop
  } parseInput: { ctrl, data in
    // Discarding all input until ready.
    data.removeAll()
  }
}

extension InputMode {
  static let input: InputMode = InputMode { ctrl in
    "Input to terminal: (Ctrl-\(ctrl.settings.actionKey.ascii) to enter control mode)\r\n"
  } onEnable: { ctrl in
    // noop
  } parseInput: { ctrl, data in
    // In input mode, data is always fully consummed.
    let action = ctrl.settings.actionKey
    // Convert CSI to SS3 cursor codes
    // "".replacing(csiCursorCode, with: { "\\033O\($0.1)" })

    if let escape = data.firstIndex(of: action.value) {
      // Send data until escape sequence.
      if (escape > 0) {
        ctrl.send(bytes: data[0..<escape])
        // drop sent data + escape sequence
        data.removeSubrange(0...escape)
      } else {
        data.removeFirst()
      }
      // Switch mode
      try ctrl.setInputMode(.action)
    } else {
      // Forward all
      ctrl.send(bytes: data)
      data.removeAll()
    }
  }
}

// MARK: -
extension InputMode {
  static let action: InputMode = InputMode { ctrl in
    let enabled = ctrl.hosts.allSatisfy(\.enabled)
    let escape = "Ctrl-\(ctrl.settings.actionKey.ascii)"
    return "Actions (Esc to exit, \(escape) to send \(escape) to input)\r\n" +
    "[c]reate window, [r]etile, s[o]rt, [e]nable/disable input, e[n]able all, " +
    // ( (!ctrl.hosts.isEmpty) && (enabled) ? "[Space] Enable next " : "") +
    "[t]oggle enabled, [m]inimise, [h]ide, [s]end text, change [b]ounds, " +
    "chan[g]e [G]rid, e[x]it\r\n";
  } onEnable: { ctrl in

  } parseInput: { ctrl, data in
    switch (data.removeFirst()) {
      case 0x1b: // escape (\e)
        try ctrl.setInputMode(.input)
      case ctrl.settings.actionKey.value:
        ctrl.send(bytes: [ctrl.settings.actionKey.value])
        try ctrl.setInputMode(.input)

/*
 if ($buffer =~ s/^r//) {
     $obj->master->arrange_windows;
     return $obj->set_mode_and_parse('input', $buffer);
 } elsif ($buffer =~ s/^o//) {
     return $obj->set_mode_and_parse('sort', $buffer);
 } elsif ($buffer =~ s/^c//) {
     return $obj->set_mode_and_parse('addhost', $buffer);
 } elsif ($buffer =~ s/^e//) {
     foreach my $window (CsshX::Master::Socket::Slave->slaves) {
         $window->unzoom;
     }
     return $obj->set_mode_and_parse('enable', $buffer);
 } elsif ($buffer =~ s/^b//) {
     return $obj->set_mode_and_parse('bounds', $buffer);
 } elsif ($buffer =~ s/^s//) {
     return $obj->set_mode_and_parse('sendstring', $buffer);
 } elsif ($buffer =~ s/^G//) {
     my $x = $config->tile_x - 1;
     $x = 1 if $x < 1;
     $config->set('tile_x', $x);
     $obj->master->arrange_windows;
 } elsif ($buffer =~ s/^g//) {
     my $x = $config->tile_x + 1;
     my $slaves = scalar CsshX::Master::Socket::Slave->slaves;
     $x = $slaves if $x > $slaves;
     $config->set('tile_x', $x);
     $obj->master->arrange_windows;
 } elsif ($buffer =~ s/^n//) {
     foreach my $window (CsshX::Master::Socket::Slave->slaves) {
         $window->unzoom;
         $window->set_disabled(0);
     }
     return $obj->set_mode_and_parse('input', $buffer);
 } elsif ($buffer =~ s/^t//) {
     foreach my $window (CsshX::Master::Socket::Slave->slaves) {
         $window->unzoom;
         $window->set_disabled(!$window->disabled);
     }
     return $obj->set_mode_and_parse('input', $buffer);
 } elsif ($buffer =~ s/^ //) {
     my @enabled = grep {
         (! $_->disabled) && $_
     } CsshX::Master::Socket::Slave->slaves;
     if (@enabled == 1) { $enabled[0]->select_next(); }
     return $obj->set_mode_and_parse('input', $buffer);
 } elsif ($buffer =~ s/^m//) {
     $_->minimise foreach (CsshX::Master::Socket::Slave->slaves);
     return $obj->set_mode_and_parse('input', $buffer);
 } elsif ($buffer =~ s/^h//) {
     $_->hide foreach (CsshX::Master::Socket::Slave->slaves);
     return $obj->set_mode_and_parse('input', $buffer);
 } elsif ($buffer =~ s/^\010//) {
     $_->hide foreach (CsshX::Master::Socket::Slave->slaves);
     $obj->master->minimise;
     return $obj->set_mode_and_parse('input', $buffer);
 }
 */
      case Character("x").asciiValue:
        ctrl.close()
      default:
          print("\u{07}")
    }
  }
}

// MARK: -
extension InputMode {
  static let bounds: InputMode = InputMode { ctrl in
    ""
  } onEnable: { ctrl in

  } parseInput: { ctrl, data in

  }
  /*
   'bounds' => {
       prompt => sub { "Move and resize master with mouse to define bounds: (Enter to accept, ".
       "Esc to cancel)\r\n".
       "(Also Arrow keys of h,j,k,l can move window, hold Ctrl to resize)\r\n".
       "[r]eset to default, [f]ull screen, [p]rint current bounds" },
       onchange => sub {
           my ($obj) = @_;
           $obj->master->format_resize;
           $obj->master->size_as_bounds;
           $_->hide foreach (CsshX::Master::Socket::Slave->slaves);
       },
       parse_buffer => sub {
           my ($obj, $buffer) = @_;
           while (length $buffer) {
               #print join(' ', map { unpack("H2", $_) } split //, $buffer)."\r\n";
               if ($buffer =~ s/^(\014|\e\[5C)//) {
                   $obj->master->grow(1,0);
               } elsif ($buffer =~ s/^(\010|\e\[5D)//) {
                   $obj->master->grow(-1,0);
               } elsif ($buffer =~ s/^(\012|\e\[5A)//) {
                   $obj->master->grow(0,1);
               } elsif ($buffer =~ s/^(\013|\e\[5B)//) {
                   $obj->master->grow(0,-1);
               } elsif ($buffer =~ s/^(l|\e\[C)//) {
                   $obj->master->move(1,0)
               } elsif ($buffer =~ s/^(h|\e\[D)//) {
                   $obj->master->move(-1,0);
               } elsif ($buffer =~ s/^(k|\e\[A)//) {
                   $obj->master->move(0,-1);
               } elsif ($buffer =~ s/^(j|\e\[B)//) {
                   $obj->master->move(0,1);
               } elsif ($buffer =~ s/^\r//) {
                   $obj->master->bounds_as_size;
                   $obj->master->format_master;
                   $obj->master->arrange_windows;
                   return $obj->set_mode_and_parse('input', $buffer);
               } elsif ($buffer =~ s/^\e//) {
                   $obj->master->format_master;
                   $obj->master->arrange_windows;
                   return $obj->set_mode_and_parse('input', $buffer);
               } elsif ($buffer =~ s/^r//) {
                   $obj->master->reset_bounds;
                   $obj->master->size_as_bounds;
               } elsif ($buffer =~ s/^p//) {
                   $obj->master->redraw;
                   my $b = $obj->master->bounds;
                   print "\r\n\r\nscreen_bounds = {".join(", ",@$b)."}\r\n";
               } elsif ($buffer =~ s/^f//) {
                   $obj->master->max_physical_bounds;
                   $obj->master->size_as_bounds;
               } else {
                   substr($buffer, 0, 1, '');
                   print "\007";
               }
           }
           $obj->set_read_buffer('');
       },
   },
   */
}

// MARK: -
extension InputMode {
  static let sendString: InputMode = InputMode { ctrl in
    return "Send string to all active windows: (Esc to exit)\r\n" +
    "[h]ostname, [c]onnection string, window [i]d, [s]lave id"
  } onEnable: { ctrl in

  } parseInput: { ctrl, data in

  }
  /*
   'sendstring' => {
       parse_buffer => sub {
           my ($obj, $buffer) = @_;
           while (length $buffer) {
               if ($buffer =~ s/^c//) {
                   foreach my $window (CsshX::Master::Socket::Slave->slaves) {
                       $window->send_input($window->hostname) unless $window->disabled;
                   }
                   return $obj->set_mode_and_parse('input', $buffer);
               } elsif ($buffer =~ s/^h//) {
                   foreach my $window (CsshX::Master::Socket::Slave->slaves) {
                       my $str = $window->hostname;
                       $str =~ s/^[^@]+@//; $str =~ s/:[^:]+$//;
                       $window->send_input($str) unless $window->disabled;
                   }
                   return $obj->set_mode_and_parse('input', $buffer);
               } elsif ($buffer =~ s/^i//) {
                   foreach my $window (CsshX::Master::Socket::Slave->slaves) {
                       $window->send_input($window->windowid) unless $window->disabled;
                   }
                   return $obj->set_mode_and_parse('input', $buffer);
               } elsif ($buffer =~ s/^s//) {
                   foreach my $window (CsshX::Master::Socket::Slave->slaves) {
                       $window->send_input($window->slaveid) unless $window->disabled;
                   }
                   return $obj->set_mode_and_parse('input', $buffer);
               } elsif ($buffer =~ s/^\e//) {
                   return $obj->set_mode_and_parse('input', $buffer);
               } else {
                   substr($buffer, 0, 1, '');
                   print "\007";
               }
           }
           $obj->set_read_buffer('');
       },
   },
   */
}

// MARK: -
extension InputMode {
  static let sort: InputMode = InputMode { ctrl in
    ""
  } onEnable: { ctrl in

  } parseInput: { ctrl, data in

  }
  /*
   'sort' => {
       prompt => sub { "Choose sort order: (Esc to exit)\r\n".
       "[h]ostname, window [i]d" },
       parse_buffer => sub {
           my ($obj, $buffer) = @_;
           while (length $buffer) {
               if ($buffer =~ s/^h//) {
                   CsshX::Master::Socket::Slave->set_sort('host');
                   $obj->master->arrange_windows;
                   return $obj->set_mode_and_parse('input', $buffer);
               } elsif ($buffer =~ s/^i//) {
                   CsshX::Master::Socket::Slave->set_sort('id');
                   $obj->master->arrange_windows;
                   return $obj->set_mode_and_parse('input', $buffer);
               } elsif ($buffer =~ s/^\e//) {
                   return $obj->set_mode_and_parse('input', $buffer);
               } else {
                   substr($buffer, 0, 1, '');
                   print "\007";
               }
           }
           $obj->set_read_buffer('');
       },
   },
   */
}

// MARK: -
extension InputMode {
  static let enable: InputMode = InputMode { ctrl in
    ""
  } onEnable: { ctrl in

  } parseInput: { ctrl, data in

  }
  /*
   'enable' => {
       prompt => sub { "Select window with Arrow keys or h,j,k,l: (Esc to exit)\r\n".
       "[e]nable input, [d]isable input, disable [o]thers, disable [O]thers and zoom, [t]oggle input" },
       onchange => sub { CsshX::Window::Slave->selection_on; },
       parse_buffer => sub {
           my ($obj, $buffer) = @_;

           while (length $buffer) {
               #print join(' ', map { unpack("H2", $_) } split //, $buffer)."\r\n";
               if ($buffer =~ s/^(l|\e\[C)//) {
                   CsshX::Window::Slave->select_move(1,0);
               } elsif ($buffer =~ s/^(h|\e\[D)//) {
                   CsshX::Window::Slave->select_move(-1,0);
               } elsif ($buffer =~ s/^(k|\e\[A)//) {
                   CsshX::Window::Slave->select_move(0,-1);
               } elsif ($buffer =~ s/^(j|\e\[B)//) {
                   CsshX::Window::Slave->select_move(0,1);
               } elsif ($buffer =~ s/^[\e\r]//) {
                   CsshX::Window::Slave->selection_off;
                   return $obj->set_mode_and_parse('input', $buffer);
               } elsif ($buffer =~ s/^d//) {
                   if (my $window = CsshX::Window::Slave->selected_window()) {
                       $window->set_disabled(1);
                   }
               } elsif ($buffer =~ s/^e//) {
                   if (my $window = CsshX::Window::Slave->selected_window()) {
                       $window->set_disabled(0);
                   }
               } elsif ($buffer =~ s/^t//) {
                   if (my $window = CsshX::Window::Slave->selected_window()) {
                       $window->set_disabled(!$window->disabled);
                   }
               } elsif ($buffer =~ s/^o//) {
                   if (my $selected = CsshX::Window::Slave->selected_window()) {
                       foreach my $window (CsshX::Master::Socket::Slave->slaves) {
                           $window->set_disabled(1) unless $window == $selected;
                       }
                       $selected->set_disabled(0);
                       CsshX::Window::Slave->selection_off;
                       return $obj->set_mode_and_parse('input', $buffer);
                   }
               } elsif ($buffer =~ s/^O//) {
                   if (my $selected = CsshX::Window::Slave->selected_window()) {
                       foreach my $window (CsshX::Master::Socket::Slave->slaves) {
                           $window->set_disabled(1) unless $window == $selected;
                       }
                       $selected->set_disabled(0);
                       CsshX::Window::Slave->selection_off;
                       $selected->zoom();
                       return $obj->set_mode_and_parse('input', $buffer);
                   }
               } else {
                   substr($buffer, 0, 1, '');
                   print "\007";
               }
           }
           $obj->set_read_buffer('');
       },
   },
   */
}

// MARK: -
extension InputMode {
  static let addHost: InputMode = InputMode(raw: false) { ctrl in
    ""
  } onEnable: { ctrl in

  } parseInput: { ctrl, data in

  }
  /*
   'addhost' => {
       prompt => sub { 'Add Host: ' },
       onchange => sub { system '/bin/stty', 'sane' },
       parse_buffer => sub {
           my ($obj, $buffer) = @_;
           if ($buffer =~ s/^([^\n]*)\e//) {
               return $obj->set_mode_and_parse('input', $buffer);
           } elsif ($buffer =~ s/^(.*?)\r?\n//) {
               my $hostname = $1;
               if (length $hostname) {
                   my $slaveid = CsshX::Master::Socket::Slave->next_slaveid;
                   my $sock = $config->sock;
                   my $login = $config->login || '';
                   my @config = @{$config->config};
                   my $slave = $obj->master->register_slave($slaveid, $hostname, undef, undef);
                   $slave->open_window(
                       __FILE__, '--slave', '--sock', $sock,
                       '--slavehost', $hostname, '--slaveid', $slaveid,
                       '--ssh', $config->ssh,
                       '--ssh_args', $config->ssh_args, '--debug', $config->debug,
                       $login  ? ( '--login',    $login  ) :(),
                       (map { ('--config', $_) } @config),
                   ) or return;

                   $slave->set_settings_set($config->slave_settings_set)
                       if $config->slave_settings_set;

                   $obj->master->arrange_windows;
               }
               return $obj->set_mode_and_parse('input', $buffer);
           }
           $obj->set_read_buffer($buffer);
       },
   },
   */
}
