//
//  Controller.swift
//  csshx
//
//  Created by Jean-Daniel Dupas.
//

import Foundation

//private let kb = "\u{001b}[4m\u{001b}[1m"  // Bold Underline
//private let kk = "\u{001b}[0m"              // Reset

// MARK: -
class Controller {
  
  let tab: Terminal.Tab?
  
  let socket: String
  let settings: Settings
  
  private var term: termios? = nil
  
  var hosts: [HostWindow] = []
  var windowManager: WindowLayoutManager
  
  private var inputMode: any InputModeProtocol = InputMode.Starting()
  
  private var buffer: [UInt8] = []
  private var stdin: DispatchIO? = nil
  
  fileprivate var listener: IOListener? = nil
  
  init(tab: Terminal.Tab?, socket: String, settings: Settings) throws {
    self.tab = tab
    self.socket = socket
    self.settings = settings
    buffer.reserveCapacity(256)
    
    windowManager = WindowLayoutManager(config: settings.layout)
    
    setControllerColors()
    layout()
  }
  
  func close() {
    stdin?.close(flags: .stop)
    listener?.close()
    hosts.forEach { $0.terminate() }
  }
  
  // MARK: - Socket
  private func onBytesAvailable(_ bytes: DispatchData) {
    buffer.append(contentsOf: bytes)
    
    // if mode changed and buffer is not empty -> reparse
    while (!buffer.isEmpty) {
      do {
        let count = buffer.count
        if let mode = try inputMode.parse(input: &buffer, self) {
          try setInputMode(mode)
        } else if (buffer.count == count) {
          // No mode change and not data consumed -> needs more data, exit the loop
          break
        }
      } catch {
        logger.error("error while processing input: \(error, privacy: .public)")
        close()
        return
      }
    }
  }
  
  func send(bytes: some ContiguousBytes) {
    let data = bytes.withUnsafeBytes(DispatchData.init(bytes:))
    for host in hosts {
      send(bytes: data, to: host)
    }
  }
  
  func send(bytes: some ContiguousBytes, to host: HostWindow) {
    let data = bytes.withUnsafeBytes(DispatchData.init(bytes:))
    send(bytes: data, to: host)
  }
  
  private func send(bytes: DispatchData, to host: HostWindow) {
    // Skip disabled hosts, and host without valid connection
    guard host.enabled, let connection = host.connection else { return }
    
    connection.write(bytes) { [self] error in
      // on error -> remove host from the host list
      if error != nil {
        logger.warning("error while forwarding data to host: \(host.host.hostname, privacy: .public)")
        terminate(host: host)
      }
    }
  }
  
  // MARK: - Input
  func prompt() {
    guard stdin != nil else { return }
    
    stty.clear()
    fwrite(str: inputMode.prompt(self), file: stdout)
  }
  
  // Note: private so an InputMode cannot try to set it in a callback
  // causing an 'inputMode' exclusive access violation.
  private func setInputMode(_ mode: some InputModeProtocol) throws {
    guard mode.id != inputMode.id else { return }
    
    logger.info("Switching input mode")
    inputMode = mode
    
    try setRawInputMode(inputMode.raw)
    // Must enable before prompt
    try inputMode.onEnable(self)
    prompt()
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
  
  func runInputLoop() throws {
    guard stdin == nil else {
      return
    }
    
    let input = DispatchIO(type: .stream,
                           fileDescriptor: STDIN_FILENO,
                           queue: .main, cleanupHandler: { [self] error in
      do {
        try setRawInputMode(false)
        // exit after restoring the input mode
        Foundation.exit(0)
      } catch {}
    })
    // disable buffering
    input.setLimit(lowWater: 1)
    stdin = input
    
    // Initialize input mode
    try setRawInputMode(inputMode.raw)
    try inputMode.onEnable(self)
    prompt()
    
    //      let winch = DispatchSource.makeSignalSource(signal: SIGWINCH)
    //      winch.setEventHandler {
    //        May be use to show live frame size in bounds mode.
    //        logger.debug("SIGWINCH event")
    //      }
    //      winch.resume()
    
    input.read { [self] bytes in
      onBytesAvailable(bytes)
    } whenDone: { [self] error in
      // unreachable, as stdin should never be done.
      if let error {
        logger.warning("stdin done with error: \(error, privacy: .public)")
        close()
      }
    }
  }
  
  // MARK: - Layout
  func layout() {
    guard let tab else { return }
    
    windowManager.layout(controller: tab, hosts: hosts)
    // Always make sure the controller window is frontmost window
    tab.window.frontmost = true
  }
  
  func setControllerColors() {
    guard let tab else { return }
    
    if let color = settings.controllerBackground {
      tab.setBackgroundColor(color: color)
    }
    
    if let color = settings.controllerTextColor {
      tab.setTextColor(color: color)
    }
  }
}

// MARK: - Controller Socket & Hosts Management
private func getPeerProcessId(socket: Int32) -> pid_t {
  var pid: pid_t = 0
  var pid_size = socklen_t(MemoryLayout.size(ofValue: pid))
  guard getsockopt(socket, SOL_LOCAL, LOCAL_PEERPID, &pid, &pid_size) == 0 else {
    logger.warning("failed to retreive socket pid: \(POSIXError.errno)")
    return 0
  }
  return pid
}

extension Controller {
  
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
          let pid = getPeerProcessId(socket: fd)
          guard pid > 0 else {
            Darwin.close(fd)
            return
          }
          
          logger.info("[\(pid)] did open connection")
          let tty = Termios.getProcessTTY(pid)
          guard tty > 0 else {
            logger.warning("[\(pid)] cannot get connected process tty. Rejecting the connection")
            Darwin.close(fd)
            return
          }
          logger.info("[\(pid)] connection tty: \(tty)")
          didOpen(socket: fd, tty: tty)
        case .failure(let error):
          logger.error("server socket error: \(error, privacy: .public)")
          close()
      }
    }
  }
  
  func ready() throws {
    if inputMode is InputMode.Starting {
      layout()
      try setInputMode(InputMode.Input())
    }
  }
  
  func add(host target: Target, whenDone done: @escaping ((any Error)?) -> Void) throws {
    let tab = try Terminal.Tab.open()
    if let profile = settings.hostWindowProfile {
      if (!tab.setProfile(profile)) {
        // TODO: print warning ?
      }
    }
    // Get window size ratio for new window and save it into the layout manager
    // It is more accurate to take it from a new window than trying to infer it from
    // the tab profile rows/columns count, as the row/columns size ratio depends the used font.
    windowManager.setDefaultWindowRatio(from: tab)
    
    let tty = tab.tty
    guard tty > 0 else {
      throw ScriptingBridgeError()
    }
    logger.info("[\(target.hostname, privacy: .public)] opening window: \(tab.windowId)/\(tab.tabIdx) (tty: \(tty))")
    
    let host = HostWindow(tab: tab, host: target, tty: tty, config: settings.hostWindow)
    host.whenDone = done
    hosts.append(host)
    
    let csshx = CommandLine.executableURL()
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
    if settings.dummy {
      args.append("--dummy")
    }

    // passing ssh args and remote command as raw arguments, and let the Terminal shell parse them
    var script = Shell.quote(args: args)
    if settings.sshArgs != nil || settings.remoteCommand != nil {
      script.append(" --extra-args")

      if let sshArgs = settings.sshArgs {
        script.append(" ")
        script.append(sshArgs)
      }

      if let remoteCommand = settings.remoteCommand {
        script.append(" -- ")
        script.append(remoteCommand)
      }
    }
    
    do {
      try tab.run(args: script, clear: true, exec: !settings.debug)
    } catch {
      // Something went wrong while starting -> abort now
      terminate(host: host)
      done(error)
      return
    }
    logger.info("did start csshx \(target.hostname, privacy: .public)")
    
    // Simple timeout scheme. Instead of scheduling a DispatchSourceTimer, and having to manage it
    // unconditonally schedule a block after delay, and test if the op is done when this block is executed.
    DispatchQueue.main.asyncAfterUnsafe(deadline: .now() + .seconds(5)) { [weak self] in
      // if operation not done yet -> cancel it.
      if let self, let done = host.whenDone {
        terminate(host: host)
        done(POSIXError(.ETIMEDOUT))
      }
    }
  }
  
  private func didOpen(socket: Int32, tty: dev_t) {
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
    
    // Notify the host it is connected
    let handshake: [UInt8] = [ 0 ]
    handshake.withUnsafeBytes { bytes in
      send(bytes: DispatchData(bytes: bytes), to: host)
    }
    
    if let done = host.whenDone {
      host.whenDone = nil
      done(nil)
      // raw input mode do not show user input and can safely reprompt
      if inputMode.raw {
        prompt()
      }
    }
    
    // Start a monitoring task. An host is not supposed to write in the connection,
    // but it help us detect when the connection is closed.
    host.connection?.read { data in
      logger.warning("[\(host, privacy: .public)] discarding unexpected input: \(data.count) bytes")
    } whenDone: { [self] error in
      logger.warning("[\(host, privacy: .public)] connection lost")
      terminate(host: host)
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
    if inputMode.raw {
      prompt()
    }
  }
}
