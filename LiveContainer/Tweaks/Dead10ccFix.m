//
//  Dead10ccFix.m
//  LiveContainer
//
//  Created by s s on 2025/5/21.
//
#include <sys/xattr.h>
#include "utils.h"
#include <unistd.h>
#include "./libproc.h"
#include <sys/stat.h>
#include <sys/xattr.h>
#include "./proc_info.h"
#include <fcntl.h>
#include <spawn.h>
#include <dlfcn.h>
@import Foundation;

//extern int _sqlite3_lockstate(const char *path, int pid);

@interface Dead10ccFix : NSObject
- (void)handleAppDidEnterBackground:(NSNotification *)notification;
@end


Dead10ccFix* fix = nil;

void initDead10ccFix(void) {

    if(NSUserDefaults.isLiveProcess) {
        fix = [[Dead10ccFix alloc] init];
        [NSNotificationCenter.defaultCenter addObserver:fix selector:@selector(handleAppDidEnterBackground:) name:NSExtensionHostDidEnterBackgroundNotification object:nil];
    } else if (NSUserDefaults.isSharedApp){
        fix = [[Dead10ccFix alloc] init];
        [NSNotificationCenter.defaultCenter addObserver:fix selector:@selector(handleAppDidEnterBackground:) name:@"UIApplicationDidEnterBackgroundNotification" object:nil];
    }
}




@implementation Dead10ccFix

- (void)handleAppDidEnterBackground:(NSNotification *)notification {
    NSSet* locks = [self _lock_lockedFilePathsIgnoring:[NSMutableSet set]];
    for(NSString* path in locks) {
        unsigned char value = 0x01;

        setxattr([path UTF8String], "com.apple.runningboard.can-suspend-locked", &value, sizeof(value),0,0);
    }
}

// https://gist.github.com/JJTech0130/07e2458df592faad1d2ba72283a0ca50
- (NSMutableSet *)_lock_lockedFilePathsIgnoring: (NSMutableSet *)ignoring {
    int pid = getpid();
    int pidinfo_size = proc_pidinfo(pid, PROC_PIDLISTFDS, 0, NULL, 0);
    if (pidinfo_size <= 0) {
        // _rbs_process_log with strerr
        return nil;
    }

    void *pidinfo = malloc(pidinfo_size);
    pidinfo_size = proc_pidinfo(pid, PROC_PIDLISTFDS, 0, pidinfo, pidinfo_size);

    NSMutableSet *openFilePaths = [NSMutableSet set];

    if (pidinfo_size >= 8) {
        uint64_t count = pidinfo_size / sizeof(struct proc_fdinfo);
        struct proc_fdinfo *fdinfo = (struct proc_fdinfo *)pidinfo;
        
        while (count--) {
            if (fdinfo->proc_fdtype == PROX_FDTYPE_VNODE) {
                struct vnode_fdinfowithpath vnodeinfo;
                //memset(&vnodeinfo, 0, 0x200); // TODO: Why not sizeof(vnodeinfo)?
                int vnodeinfo_size = proc_pidfdinfo(pid, fdinfo->proc_fd, PROC_PIDFDVNODEPATHINFO, &vnodeinfo, sizeof(vnodeinfo));
                if (vnodeinfo_size == 0) {
                    // _rbs_process_log with %{public}@ proc_pidfdinfo failed for fd %d with errno %d
                    continue;
                } else if (vnodeinfo_size < sizeof(vnodeinfo)) {
                    // _rbs_process_log with %{public}@ Weird size (%d != %lu) for fd %d
                    continue;
                }

                int64_t pathlen = strlen(vnodeinfo.pvip.vip_path);
                if (pathlen == 0) {
                    // _rbs_process_log with%{public}@ nodeFDInfo.pvip.vip_path is empty for one fd
                    continue;
                }

                NSString *path = [[NSFileManager defaultManager] stringWithFileSystemRepresentation:vnodeinfo.pvip.vip_path length:pathlen];
                if (path == nil) {
                    continue;
                }

                path = [path stringByStandardizingPath];
                [openFilePaths addObject:path];
            }
            fdinfo++;
        }
    }

    NSMutableSet *lockedFilePaths = [NSMutableSet set];

    for (NSString *path in openFilePaths) {
        char *path_c = (char *)[path UTF8String];
        struct stat statbuf;
        if (stat(path_c, &statbuf) != 0) {
            // _rbs_process_log with %{public}@ Could not stat %{public}@: %{public}s
            NSLog(@"Could not stat %@: %s", path, strerror(errno));
            continue;
        }

        if ((statbuf.st_mode & S_IFMT) != S_IFREG) {
            // _rbs_process_log with %{public}@ Not checking lock on special file: %{public}@
            NSLog(@"Not checking lock on special file: %@", path);
            continue;
        }

        for (NSString *ignoringPath in ignoring) {
            if ([path hasPrefix:ignoringPath]) {
                // _rbs_process_log with %{public}@: Ignoring file %{public}@ because it is in an allowed path:  %{public}@
                NSLog(@"Ignoring file %@ because it is in an allowed path: %@", path, ignoringPath);
                continue;
            }
        }

        if ([path hasSuffix:@"-shm"] || [path hasSuffix:@"-wal"] || [path hasSuffix:@"-journal"]) {
            // _rbs_process_log with %{public}@ Ignoring SQLite journal file: %{public}@
            NSLog(@"Ignoring SQLite journal file: %@", path);
            continue;
        }

        if (getxattr(path_c, "com.apple.runningboard.can-suspend-locked", NULL, 0, 0, 0) == 1) {
            char value;
            getxattr(path_c, "com.apple.runningboard.can-suspend-locked", &value, sizeof(value), 0, 0);
            if (value != 0) {
                // _rbs_process_log with %{public}@ Ignoring file with can-suspend-locked: %{public}@
                NSLog(@"Ignoring file with can-suspend-locked: %@", path);
                continue;
            }
        }
        int (*_sqlite3_lockstate)(char*, int) = dlsym(RTLD_DEFAULT, "_sqlite3_lockstate");
        int sqlite_lock = _sqlite3_lockstate(path_c, pid);
        if (sqlite_lock == 0) {
            // _rbs_process_log with %{public}@ Ignoring unlocked SQLite database: %{public}@
            NSLog(@"Ignoring unlocked SQLite database: %@", path);
            continue;
        }

        if (sqlite_lock == 1) {
            // _rbs_process_log with %{public}@ Found locked SQLite database: %{public}@
            NSLog(@"Found locked SQLite database: %@", path);
            [lockedFilePaths addObject:path];
            
        } else {
            int fd = open(path_c, O_RDONLY | O_NOCTTY);
            if (fd <= 1) {
                continue;
            }

            struct flock fl;
            memset(&fl, 0, sizeof(fl));
            fl.l_type = F_WRLCK;
            fl.l_pid = pid;

            int lock = fcntl(fd, F_GETLKPID, &fl);
            if (lock == -1) {
                continue;
            }

            if ((fl.l_type &~ F_UNLCK) == 1) {
                // _rbs_process_log with %{public}@ Found locked file lock: %{public}@
                NSLog(@"Found locked file lock: %@", path);
                [lockedFilePaths addObject:path];
            }
        }
    }

    return lockedFilePaths;
}

@end
