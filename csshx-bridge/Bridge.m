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

extern int pthread_chdir_np(char *path);
extern int pthread_fchdir_np(int fd);

@implementation Termios

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

+ (BOOL)tiocsti:(uint8_t)c error:(NSError **)error {
  const char value = c;
  if (ioctl(fileno(stdin), TIOCSTI, &value) < 0) {
    *error = [[NSError alloc] initWithDomain:NSPOSIXErrorDomain code:errno userInfo:nil];
    return false;
  }
  return true;
}

@end

@implementation Socket

static
dispatch_fd_t _socket(NSString *path, NSError **error, int (^op)(dispatch_fd_t, const struct sockaddr_un *, socklen_t sock_len)) {
  NSString *dir = [path stringByDeletingLastPathComponent];
  NSString *filename = [path lastPathComponent];

  if (!dir || !filename || !op) {
    *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:EINVAL userInfo:nil];
    return 0;
  }

  struct sockaddr_un sockaddr = {};
  sockaddr.sun_len = sizeof(sockaddr);
  sockaddr.sun_family = AF_UNIX;
  // Note: in case the length limitation is an issue, consider using chdir and relative path.
  if (strlcpy(sockaddr.sun_path, filename.fileSystemRepresentation, sizeof(sockaddr.sun_path)) >= sizeof(sockaddr.sun_path)) {
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

  if (pthread_chdir_np((char *)dir.fileSystemRepresentation) < 0) {
    *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:nil];
    close(sock);
    return 0;
  }

  int err = op(sock, &sockaddr, socklen(&sockaddr));
  if (err != 0) {
    *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:nil];
    pthread_fchdir_np(-1);
    close(sock);
    return 0;
  }

  pthread_fchdir_np(-1);
  return sock;
}

static inline socklen_t socklen(struct sockaddr_un *addr) {
  return (socklen_t)SUN_LEN(addr);
}

+ (dispatch_fd_t)connect:(NSString *)path error:(NSError **)error {
  return _socket(path, error, ^int(dispatch_fd_t sock, const struct sockaddr_un *addr, socklen_t sock_len) {
    if (connect(sock, (const struct sockaddr *)addr, sock_len) < 0 && errno != EINPROGRESS) {
      return errno;
    }

    return 0;
  });
}

+ (dispatch_fd_t)bind:(NSString *)path umask:(mode_t)mode error:(NSError **)error {
  return _socket(path, error, ^int(dispatch_fd_t sock, const struct sockaddr_un *addr, socklen_t sock_len) {
    // Ensure the file does not exists before binding
    unlink(addr->sun_path);

    mode_t mask = umask(mode);
    if (bind(sock, (const struct sockaddr *)addr, sock_len) < 0) {
      int err = errno;
      umask(mask);
      return err;
    }
    umask(mask);
    return 0;
  });
}

@end
