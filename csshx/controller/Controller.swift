//
//  ControllerUI.swift
//  csshx
//
//  Created by Jean-Daniel Dupas on 18/10/2023.
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

  private var inputMode: InputMode = .starting

  private var buffer: [UInt8] = []
  private var stdin: DispatchIO? = nil

  fileprivate var listener: IOListener? = nil

  init(tab: Terminal.Tab?, socket: String, settings: Settings) throws {
    self.tab = tab
    self.socket = socket
    self.settings = settings
    buffer.reserveCapacity(256)

    windowManager = try WindowLayoutManager(screens: settings.screens, 
                                            bounds: settings.screenBounds,
                                            controllerHeight: settings.controllerHeight)
    layoutControllerWindow()
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

  // MARK: - Input
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

  // MARK: - Layout
  fileprivate func layout() {
    // Update controller window
    layoutControllerWindow()

    // Update other windows
  }

  private func layoutControllerWindow() {
    guard let tab else { return }

    if let color = settings.controllerBackground {
      tab.setBackgroundColor(color: color)
    }

    if let color = settings.controllerForeground {
      tab.setTextColor(color: color)
    }

    windowManager.layout(controller: tab)
    tab.window.frontmost = true
  }
}

// MARK: - Controller Socket & Hosts Management
private func getPeerProcessId(socket: Int32) -> pid_t {
  var pid: pid_t = 0
  var pid_size = socklen_t(MemoryLayout.size(ofValue: pid))
  guard getsockopt(socket, SOL_LOCAL, LOCAL_PEERPID, &pid, &pid_size) == 0 else {
    logger.warning("failed to retreive socket pid: \(errno)")
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
          logger.info("[\(pid)] did open connection")
          let tty = Bridge.getProcessTTY(pid)
          guard tty > 0 else {
            logger.warning("[\(pid)] cannot get connected process tty. Rejecting the connection")
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

  func ready() throws {
    if inputMode == .starting {
      // TODO: layout hosts window
      layout()
      try setInputMode(.input)
    }
  }
  
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

    if let done = host.whenDone {
      // TODO: update prompt if dynamic
      host.whenDone = nil
      done(nil)
    }

    // Start a monitoring task. An host is not supposed to write in the connection,
    // but it help us detect when the connection is closed.
    host.connection?.read {data in
      logger.warning("[\(host)] discarding unexpected input: \(data.count) bytes")
    } whenDone: {  [self] error in
      logger.warning("[\(host)] connection lost")
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
  }
}
