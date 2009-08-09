#include "FortunateSonServer.h"
#include <stdio.h>

kern_return_t _FortunateSonSayHey(mach_port_t server, FilePath path, int *result) {
    printf("Hey guys this is my function %s\n", path);
    *result = 12345;
    return KERN_SUCCESS;
}
