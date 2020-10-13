#include <stdint.h>

typedef const char *FilePath;
typedef unsigned char *VarData_t;
typedef long long FileOffset_t;

enum {
    VMRegionUnmapped = 1 << 0,
    VMRegionReadable = 1 << 1,
    VMRegionWritable = 1 << 2,
    VMRegionExecutable = 1 << 3,
    VMRegionShared = 1 << 4
};
typedef uint32_t VMRegionAttributes;
