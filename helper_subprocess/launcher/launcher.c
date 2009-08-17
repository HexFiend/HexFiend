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
    if (argc != 2) fail("Not enough arguments: %d", argc);
    int err = 0;
    
    int srcFD = open(argv[1], O_RDONLY);
    if (srcFD < 0) {
        err = errno;
        fail("Could not open file at path '%s' because of error error %d: %s", argv[1], err, strerror(err));        
    }
    
    /* Get the temp directory */
    char dstPath[PATH_MAX + 1];
    /* We could use confstr() below, but this gives us the temp directory for the root user, which we do not have access to.  So just use /tmp. */
#if 0
    if (0 == confstr(_CS_DARWIN_USER_TEMP_DIR, dstPath, sizeof dstPath)) {
        err = errno;
        fail("confstr() returned error %d: %s", err, strerror(err));
    }
#endif
    strcpy(dstPath, "/tmp/");
    
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

    /* Output the destination, and no error message, and then wait to be told to go */
    puts(dstPath);
    puts("");
    fflush(stdout);
    
    char readBuff[256];
    fgets(readBuff, sizeof readBuff, stdin);
    if (0 == strcmp(readBuff, "OK\n")) {
        /* Our parent has executed the file, so unlink it so nobody else can execute it */
        unlink(dstPath);
    }

    
    /* Close the destination */
    close(srcFD);
    
    return 0;
}
