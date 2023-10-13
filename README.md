#  CsshX Swift Port


### Design

 When launched by user invocation, `csshx` validate user input, starts a `csshx-controller` in a new `Terminal` window, and exits.
  
 `csshx-controller` is where all the work is done:
   * Parse configuration and arguments, and creates the hosts list. 
   * Create a Unix socket, and start listening on it.
   * For each host, it starts a `csshx-host` process in new `Terminal` window.
   * Listen for user input on `stdin` and forward it to the connected `csshx-hosts`
   * Handle user commands when switching to configuration mode.
    
 `csshx-host` is a leighweight ssh wrapper that perform the following tasks:
   * Connect to the `csshx-controller` socket.
   * Spawn a `ssh` process.
   * Notify the controller that it is ready, and start forwarding `controller` input to the `Terminal`.
 
