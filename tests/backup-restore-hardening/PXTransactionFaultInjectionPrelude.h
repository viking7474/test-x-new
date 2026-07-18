#import <Foundation/Foundation.h>

#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <stdarg.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <sys/file.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>

#ifdef __cplusplus
extern "C" {
#endif

int PXFI_open(const char *path, int flags, ...);
int PXFI_openat(int directoryDescriptor, const char *path, int flags, ...);
int PXFI_close(int descriptor);
int PXFI_dup(int descriptor);
int PXFI_fcntl(int descriptor, int command, ...);
int PXFI_flock(int descriptor, int operation);
int PXFI_fstat(int descriptor, struct stat *value);
int PXFI_fstatat(int directoryDescriptor, const char *path, struct stat *value, int flags);
int PXFI_lstat(const char *path, struct stat *value);
int PXFI_fchmod(int descriptor, mode_t mode);
off_t PXFI_lseek(int descriptor, off_t offset, int whence);
int PXFI_mkdirat(int directoryDescriptor, const char *path, mode_t mode);
int PXFI_renameat(int sourceDirectoryDescriptor,
                  const char *sourcePath,
                  int destinationDirectoryDescriptor,
                  const char *destinationPath);
int PXFI_unlinkat(int directoryDescriptor, const char *path, int flags);
int PXFI_fsync(int descriptor);
ssize_t PXFI_write(int descriptor, const void *bytes, size_t length);
ssize_t PXFI_read(int descriptor, void *bytes, size_t length);
DIR *PXFI_fdopendir(int descriptor);
struct dirent *PXFI_readdir(DIR *directory);
int PXFI_closedir(DIR *directory);

#ifdef __cplusplus
}
#endif

#if PX_TRANSACTION_FAULT_INJECTION
#define open PXFI_open
#define openat PXFI_openat
#define close PXFI_close
#define dup PXFI_dup
#define fcntl PXFI_fcntl
#define flock PXFI_flock
#define fstat PXFI_fstat
#define fstatat PXFI_fstatat
#define lstat PXFI_lstat
#define fchmod PXFI_fchmod
#define lseek PXFI_lseek
#define mkdirat PXFI_mkdirat
#define renameat PXFI_renameat
#define unlinkat PXFI_unlinkat
#define fsync PXFI_fsync
#define write PXFI_write
#define read PXFI_read
#define fdopendir PXFI_fdopendir
#define readdir PXFI_readdir
#define closedir PXFI_closedir
#endif
