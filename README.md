# CsshX Swift Port


### Design

 When launched by user invocation, `csshx` validate user input, starts a `csshx-controller` in a new `Terminal` window, and exits.
  
 `csshx-controller` is where all the work is done:
   * Parse configuration and arguments, and creates the hosts list. 
   * Create a Unix socket, and start listening on it.
   * For each host, it starts a `csshx-host` process in new `Terminal` window.
   * Listen for user input on `stdin` and forward it to the connected `csshx-hosts`
   * Handle user commands when switching to configuration mode.
    
 `csshx-host` is a lightweight ssh wrapper that performs the following tasks:
   * Connect to the `csshx-controller` socket.
   * Spawn a `ssh` process.
   * Wait for the controller signal telling it the connection is ready, and start forwarding `controller` input to the `Terminal`.
 
To known which `csshx-host` connection matches which Terminal window, the controller extracts the `csshx-host` pid from 
the unix socket connection and lookup the process info to get its matching tty. It can than and compare it to the Terminal window's TTY. 

### Differences with csshX

#### Ping Test

  Ping test is not implemented on v 1.0.0, but it is expected to have a slighlty different design. It will default 
  to using icmp request to ping the host, and not a full TCP connect round-trip. It means that it will send request 
  per host, and not a request per host/port pair. 
  
  A TCP mode may be implemented, but as it is almost as wastefull to do that than simply trying to launch ssh and fail
  on connection failure, that it may not be worse, unless there is a compelling usecase.
  
#### Space support

  This version does not support moving windows accross spaces. It was broken in the orignal csshx version anyway.
  
#### Multiscreen support

  Unlike the original csshX, this implementation does not assume a rectangulare screen space when using multiple screens.
  Instead, it try to configure and layout SSH windows on each screen independently. 
  
  It means that customizing the multi screen configuration is more complex than with the original implementation, but it supports
  any kind of screens disposition, and more important, SSH windows will always fit on a single screen, and not be on screens boundaries.
  
  It also imply that commands to change the screen layout works per screen instead of globally. For instance, when using the command to choose
  the screen bounds, each screen should be configured separately, just like when changing the rows/columns count (this is a per screen setting). 
  
  This version also has a concept of screen weight, which is use to define how many windows to put on each screen (a small screen may contains less windows
  than a large screen). The screen weight is currently not exposed and is not configurable, but may be if there is need for it.
