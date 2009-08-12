#include <stdio.h>
#include <stdlib.h>
#include <copyfile.h>
#include <unistd.h>
#include <limits.h>
#include <stdarg.h>
#include <errno.h>
#include <fcntl.h>
#include <string.h>
#include <sys/stat.h>

/* The process (launched with AuthorizationExecuteWithPrivileges) that's responsible for copying the helper tool to /tmp */

#define TMP_SUFFIX "XXXXXXXX"

static void fail(const char *fmt, ...) __attribute__ ((format (printf, 1, 2)));
static void fail(const char *fmt, ...) {
    puts(""); //output an empty path
    va_list argp;
    va_start(argp, fmt);
    vfprintf(stdout, fmt, argp);
    va_end(argp);
    putchar('\n');
    fflush(stdout);
    exit(-1);
}

int main(int argc, char *argv[]) {
    sleep(100);
    if (argc != 2) fail("Not enough arguments.");
    int err = 0;
    
    int srcFD = open(argv[1], O_RDONLY);
    if (srcFD < 0) {
        err = errno;
        fail("Could not open file at path '%s' because of error error %d: %s", argv[1], err, strerror(err));        
    }
    
    /* Get the temp directory */
    char dstPath[PATH_MAX + 1];
    if (0 == confstr(_CS_DARWIN_USER_TEMP_DIR, dstPath, sizeof dstPath)) {
        err = errno;
        fail("confstr() returned error %d: %s", err, strerror(err));
    }
    
    /* Append our suffix */
    const char *pathCompnent = "HexFiend_PrivilegedSon_." TMP_SUFFIX;
    if (strlcat(dstPath, pathCompnent, sizeof dstPath) >= sizeof dstPath) {
        fail("Path was too long");
    }
    
    int dstFD = mkstemp(dstPath);
    if (dstFD < 0) {
        err = errno;
        fail("mkstemps() returned error %d: %s", err, strerror(err));
    }
    
    /* Try copying the file */
    errno = 0;
    if (fcopyfile(srcFD, dstFD, NULL, COPYFILE_DATA) < 0) {
        err = errno;
        fail("fcopyfile failed with error %d: %s", err, strerror(err));
    }

    /* Close the source */
    close(srcFD);
    
    /* Make the file executable, and setuid */
    if (fchmod(dstFD, 0555 | S_ISUID) < 0) {
        err = errno;
        fail("fchmod failed with error %d: %s", err, strerror(err));        
    }
    
    /* Close the destination */
    close(srcFD);
    
    puts(dstPath);
    puts(""); //no error message
    return 0;
}
