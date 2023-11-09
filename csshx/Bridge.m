//
//  Bridge.m
//  csshx
//
//  Created by Jean-Daniel Dupas.
//

#import "Bridge.h"

#import <libc.h>
#import <sys/un.h>
#import <sys/sysctl.h>

@implementation Bridge

+ (BOOL)tiocsti:(uint8_t)c error:(NSError **)error {
  const char value = c;
  if (ioctl(fileno(stdin), TIOCSTI, &value) < 0) {
    *error = [[NSError alloc] initWithDomain:NSPOSIXErrorDomain code:errno userInfo:nil];
    return false;
  }
  return true;
}

static
dispatch_fd_t _socket(NSString *path, struct sockaddr_un *sockaddr, NSError **error) {
  const char *fspath = [path fileSystemRepresentation];
  if (!fspath || !sockaddr) {
    *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:EINVAL userInfo:nil];
    return 0;
  }

  sockaddr->sun_len = sizeof(*sockaddr);
  sockaddr->sun_family = AF_UNIX;
  // Note: in case the length limitation is an issue, consider using chdir and relative path.
  if (strlcpy(sockaddr->sun_path, fspath, sizeof(sockaddr->sun_path)) >= sizeof(sockaddr->sun_path)) {
    *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:ENAMETOOLONG userInfo:nil];
    return 0;
  }

  dispatch_fd_t sock = socket(PF_UNIX, SOCK_STREAM, 0);
  if (sock < 0) {
    *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:nil];
    return 0;
  }
  // Make sure the socket is non blocking
  if (fcntl(sock, F_SETFL, O_NONBLOCK) != 0) {
    *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:nil];
    close(sock);
    return 0;
  }

  return sock;
}

+ (dev_t)getProcessTTY:(pid_t)pid {
  struct kinfo_proc info;
  size_t length = sizeof(struct kinfo_proc);
  int mib[4] = { CTL_KERN, KERN_PROC, KERN_PROC_PID, pid };
  if (sysctl(mib, 4, &info, &length, NULL, 0) < 0)
    return 0;
  if (length == 0)
    return 0;

  return info.kp_eproc.e_tdev;
}

static inline socklen_t socklen(struct sockaddr_un *addr) {
  return (socklen_t)SUN_LEN(addr);
}

+ (dispatch_fd_t)connect:(NSString *)path error:(NSError **)error {
  struct sockaddr_un addr = {};
  dispatch_fd_t sock = _socket(path, &addr, error);
  if (sock <= 0)
    return 0;

  if (connect(sock, (struct sockaddr *)&addr, socklen(&addr)) < 0) {
    int err = errno;
    if (err != EINPROGRESS) {
      *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:err userInfo:nil];
      close(sock);
    }
    return 0;
  }
  return sock;
}

+ (dispatch_fd_t)bind:(NSString *)path umask:(mode_t)mode error:(NSError **)error {
  struct sockaddr_un addr = {};
  dispatch_fd_t sock = _socket(path, &addr, error);
  if (sock <= 0)
    return 0;

  // Ensure the file does not exists before binding
  unlink([path fileSystemRepresentation]);
  // mode_t mask = umask(mode);
  if (bind(sock, (struct sockaddr *)&addr, socklen(&addr)) < 0) {
    *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:nil];
    // umask(mask);
    close(sock);
    return 0;
  }
  // umask(mask);
  return sock;
}

@end
