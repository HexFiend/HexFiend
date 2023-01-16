//
//  HFTclTemplateController.m
//  HexFiend_2
//
//  Created by Kevin Wojniak on 1/6/18.
//  Copyright © 2018 ridiculous_fish. All rights reserved.
//

#import "HFTclTemplateController.h"
#import <tcl.h>
#import <tclTomMath.h>
#import <zlib.h>
#import <HexFiend/HFEncodingManager.h>
#import "version.h"

// Tcl_ParseArgsObjv was added in Tcl 8.6, but macOS ships with Tcl 8.5
#import "Tcl_ParseArgsObjv.h"

static Tcl_Obj* tcl_obj_from_uint64(uint64_t value) {
    char buf[21];
    const size_t num_bytes = snprintf(buf, sizeof(buf), "%" PRIu64, value);
    return Tcl_NewStringObj(buf, (int)num_bytes);
}

enum command {
    command_uint64,
    command_int64,
    command_uint32,
    command_int32,
    command_uint24,
    command_uint16,
    command_int16,
    command_uint8,
    command_int8,
    command_big_endian,
    command_little_endian,
    command_float,
    command_double,
    command_macdate,
    command_fatdate,
    command_fattime,
    command_unixtime32,
    command_unixtime64,
    command_bytes,
    command_hex,
    command_ascii,
    command_utf16,
    command_str,
    command_cstr,
    command_uuid,
    command_move,
    command_goto,
    command_pos,
    command_len,
    command_end,
    command_include,
    command_requires,
    command_section,
    command_endsection,
    command_sectionname,
    command_sectionvalue,
    command_sectioncollapse,
    command_zlib_uncompress,
    command_entry,
    command_uint8_bits,
    command_uint16_bits,
    command_uint32_bits,
    command_uint64_bits,
    command_hf_min_version_required,
    command_uleb128,
    command_sleb128,
};

long versionInteger(long major, long minor, long patch) {
    HFASSERT(major > 0);
    HFASSERT(minor >= 0 && minor <= 999);
    HFASSERT(patch >= 0 && patch <= 99);

    return major * 100000 + minor * 100 + patch;
}

#define HF_XSTR(s) HF_STR(s)
#define HF_STR(s) #s
static const char* kVersionString = HF_XSTR(HEXFIEND_VERSION);
#undef HF_STR
#undef HF_XSTR

@interface HFTclTemplateController ()

- (int)runCommand:(enum command)command objc:(int)objc objv:(struct Tcl_Obj * CONST *)objv;

@end

#define DEFINE_COMMAND(name) \
    int cmd_##name(ClientData clientData, Tcl_Interp *interp __unused, int objc, struct Tcl_Obj * CONST * objv) { \
        return [(__bridge HFTclTemplateController *)clientData runCommand:command_##name objc:objc objv:objv]; \
    }

DEFINE_COMMAND(uint64)
DEFINE_COMMAND(int64)
DEFINE_COMMAND(uint32)
DEFINE_COMMAND(int32)
DEFINE_COMMAND(uint24)
DEFINE_COMMAND(uint16)
DEFINE_COMMAND(int16)
DEFINE_COMMAND(uint8)
DEFINE_COMMAND(int8)
DEFINE_COMMAND(float)
DEFINE_COMMAND(double)
DEFINE_COMMAND(macdate)
DEFINE_COMMAND(fatdate)
DEFINE_COMMAND(fattime)
DEFINE_COMMAND(unixtime32)
DEFINE_COMMAND(unixtime64)
DEFINE_COMMAND(big_endian)
DEFINE_COMMAND(little_endian)
DEFINE_COMMAND(bytes)
DEFINE_COMMAND(hex)
DEFINE_COMMAND(ascii)
DEFINE_COMMAND(utf16)
DEFINE_COMMAND(str)
DEFINE_COMMAND(cstr)
DEFINE_COMMAND(uuid)
DEFINE_COMMAND(move)
DEFINE_COMMAND(goto)
DEFINE_COMMAND(pos)
DEFINE_COMMAND(len)
DEFINE_COMMAND(end)
DEFINE_COMMAND(include)
DEFINE_COMMAND(requires)
DEFINE_COMMAND(section)
DEFINE_COMMAND(endsection)
DEFINE_COMMAND(sectionname)
DEFINE_COMMAND(sectionvalue)
DEFINE_COMMAND(sectioncollapse)
DEFINE_COMMAND(zlib_uncompress)
DEFINE_COMMAND(entry)
DEFINE_COMMAND(uint8_bits)
DEFINE_COMMAND(uint16_bits)
DEFINE_COMMAND(uint32_bits)
DEFINE_COMMAND(uint64_bits)
DEFINE_COMMAND(hf_min_version_required)
DEFINE_COMMAND(uleb128)
DEFINE_COMMAND(sleb128)

@implementation HFTclTemplateController {
    Tcl_Interp *_interp;
}

- (instancetype)init {
    if ((self = [super init]) == nil) {
        return nil;
    }

    _interp = Tcl_CreateInterp();
    if (Tcl_Init(_interp) != TCL_OK) {
        fprintf(stderr, "Tcl_Init error: %s\n", Tcl_GetStringResult(_interp));
        return nil;
    }

    struct command {
        const char *name;
        Tcl_ObjCmdProc *proc;
    };
#define CMD_STR(type) #type
#define CMD_NAMED(name, type) {name, cmd_##type}
#define CMD(type) CMD_NAMED(CMD_STR(type), type)
    const struct command commands[] = {
        CMD(uint64),
        CMD(int64),
        CMD(uint32),
        CMD(int32),
        CMD(uint24),
        CMD(uint16),
        CMD(int16),
        CMD(uint8),
        CMD_NAMED("byte", uint8),
        CMD(int8),
        CMD(float),
        CMD(double),
        CMD(macdate),
        CMD(fatdate),
        CMD(fattime),
        CMD(unixtime32),
        CMD(unixtime64),
        CMD(big_endian),
        CMD(little_endian),
        CMD(bytes),
        CMD(hex),
        CMD(ascii),
        CMD(utf16),
        CMD(str),
        CMD(cstr),
        CMD(uuid),
        CMD(move),
        CMD(goto),
        CMD(pos),
        CMD(len),
        CMD(end),
        CMD(include),
        CMD(requires),
        CMD(section),
        CMD(endsection),
        CMD(sectionname),
        CMD(sectionvalue),
        CMD(sectioncollapse),
        CMD(zlib_uncompress),
        CMD(entry),
        CMD(uint8_bits),
        CMD(uint16_bits),
        CMD(uint32_bits),
        CMD(uint64_bits),
        CMD(hf_min_version_required),
        CMD(uleb128),
        CMD(sleb128),
    };
#undef CMD
#undef CMD_NAMED
    for (size_t i = 0; i < sizeof(commands) / sizeof(commands[0]); ++i) {
        Tcl_CmdInfo info;
        if (Tcl_GetCommandInfo(_interp, commands[i].name, &info) != TCL_OK) {
            NSLog(@"Warning: replacing existing command \"%s\"", commands[i].name);
        }
        Tcl_CreateObjCommand(_interp, commands[i].name, commands[i].proc, (__bridge ClientData)self, NULL);
    }

    return self;
}

- (void)dealloc {
    if (_interp) {
        Tcl_DeleteInterp(_interp);
    }
}

- (NSString *)evaluateScript:(NSString *)path {
    Tcl_LimitTypeSet(_interp, TCL_LIMIT_TIME);
    Tcl_Time time;
    Tcl_GetTime(&time);
    time.sec += [[NSUserDefaults standardUserDefaults] integerForKey:@"BinaryTemplateScriptTimeout"];
    Tcl_LimitSetTime(_interp, &time);
    const int err = Tcl_EvalFile(_interp, [path fileSystemRepresentation]);
    if (err != TCL_OK) {
        Tcl_Obj *options = Tcl_GetReturnOptions(_interp, err);
        Tcl_Obj *key = Tcl_NewStringObj("-errorinfo", -1);
        Tcl_Obj *value = NULL;
        Tcl_IncrRefCount(key);
        Tcl_DictObjGet(NULL, options, key, &value);
        Tcl_DecrRefCount(key);
        if (value) {
            return [NSString stringWithUTF8String:Tcl_GetStringFromObj(value, NULL)];
        }
    }
    return nil;
}

#define CHECK_SINGLE_ARG(s) \
    if (objc != 2) { \
        Tcl_WrongNumArgs(_interp, 0, objv, s); \
        return TCL_ERROR; \
    }

#define CHECK_NO_ARG \
    if (objc != 1) { \
        Tcl_WrongNumArgs(_interp, 0, objv, NULL); \
        return TCL_ERROR; \
    }

- (int)getLength:(long *)length objv:(Tcl_Obj *)objPtr allowEOF:(BOOL)allowEOF {
    _Static_assert(sizeof(long) == sizeof(unsigned long long), "invalid long");
    *length = 0;
    if (allowEOF) {
        const char *str = Tcl_GetStringFromObj(objPtr, NULL);
        if (str && strcmp(str, "eof") == 0) {
            *length = self.length - (self.anchor + self.position);
            return TCL_OK;
        }
    }
    int err = Tcl_GetLongFromObj(_interp, objPtr, length);
    if (err != TCL_OK) {
        return err;
    }
    if (*length <= 0) {
        Tcl_SetObjResult(_interp, Tcl_ObjPrintf("Length must be greater than 0, but was %ld.", *length));
        return TCL_ERROR;
    }
    return err;
}

- (int)getOffset:(long *)offset objv:(Tcl_Obj *)objPtr {
    *offset = 0;
    int err = Tcl_GetLongFromObj(_interp, objPtr, offset);
    if (err != TCL_OK) {
        return err;
    }
    if (*offset < 0) {
        Tcl_SetObjResult(_interp, Tcl_ObjPrintf("Offset must be >= 0, but was %ld", *offset));
        return TCL_ERROR;
    }
    return err;
}

- (BOOL) parseVersionString:(NSString*)s major:(int*)major minor:(int*)minor patch:(int*)patch {
    if (!s || !major || !minor || !patch) return false;

    *major = *minor = *patch = 0;

    NSArray<NSString *> *components = [s componentsSeparatedByString:@"."];
    NSUInteger count = components.count;

    if (count == 0 || count > 3) {
        return NO;
    }

    if (count > 0) {
        *major = [components[0] intValue];
    }

    if (count > 1) {
        *minor = [components[1] intValue];
    }

    if (count > 2) {
        *patch = [components[2] intValue];
    }

    return YES;
}

- (long) haveVersion {
    static long have_version_s = 0;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        int have_major;
        int have_minor;
        int have_patch;

        if (![self parseVersionString:[NSString stringWithUTF8String:kVersionString] major:&have_major minor:&have_minor patch:&have_patch]) {
            return; // need better error handling here?
        }

        have_version_s = versionInteger(have_major, have_minor, have_patch);
    });

    return have_version_s;
}


- (int)runCommand:(enum command)command objc:(int)objc objv:(struct Tcl_Obj * CONST *)objv {
    switch (command) {
        case command_uint64:
        case command_int64:
        case command_uint32:
        case command_int32:
        case command_uint24:
        case command_uint16:
        case command_int16:
        case command_uint8:
        case command_int8:
        case command_float:
        case command_double:
        case command_macdate:
        case command_fatdate:
        case command_fattime:
        case command_unixtime32:
        case command_unixtime64:
        case command_uuid:
            return [self runTypeCommand:command objc:objc objv:objv];
        case command_big_endian: {
            CHECK_NO_ARG
            self.endian = HFEndianBig;
            break;
        }
        case command_little_endian: {
            CHECK_NO_ARG
            self.endian = HFEndianLittle;
            break;
        }
        case command_bytes:
        case command_hex:
        case command_ascii:
        case command_utf16: {
            if (objc != 2 && objc != 3) {
                Tcl_WrongNumArgs(_interp, 1, objv, "len [label]");
                return TCL_ERROR;
            }
            long len;
            int err = [self getLength:&len objv:objv[1] allowEOF:YES];
            if (err != TCL_OK) {
                return err;
            }
            NSString *label = nil;
            if (objc == 3) {
                label = [NSString stringWithUTF8String:Tcl_GetStringFromObj(objv[2], NULL)];
            }
            if (command == command_bytes) {
                NSData *data = [self readBytesForSize:len forLabel:label];
                if (!data) {
                    Tcl_SetObjResult(_interp, Tcl_ObjPrintf("Failed to read %ld bytes", len));
                    return TCL_ERROR;
                }
                Tcl_SetObjResult(_interp, Tcl_NewByteArrayObj(data.bytes, (int)data.length));
                break;
            }
            NSString *str = nil;
            switch (command) {
                case command_hex:
                    str = [self readHexDataForSize:len forLabel:label];
                    break;
                case command_ascii: {
                    HFStringEncoding *encodingObj = [[HFEncodingManager shared] systemEncoding:NSASCIIStringEncoding];
                    str = [self readStringDataForSize:len encoding:encodingObj forLabel:label];
                    break;
                }
                case command_utf16: {
                    NSStringEncoding encoding = self.endian == HFEndianLittle ? NSUTF16LittleEndianStringEncoding : NSUTF16BigEndianStringEncoding;
                    HFStringEncoding *encodingObj = [[HFEncodingManager shared] systemEncoding:encoding];
                    str = [self readStringDataForSize:len encoding:encodingObj forLabel:label];
                    break;
                }
                default:
                    HFASSERT(0);
                    break;
            }
            if (!str) {
                Tcl_SetObjResult(_interp, Tcl_ObjPrintf("Failed to read %ld bytes", len));
                return TCL_ERROR;
            }
            Tcl_SetObjResult(_interp, Tcl_NewStringObj(str.UTF8String, -1));
            break;
        }
        case command_str: {
            if (objc != 3 && objc != 4) {
                Tcl_WrongNumArgs(_interp, 1, objv, "len encoding [label]");
                return TCL_ERROR;
            }
            long len;
            int err = [self getLength:&len objv:objv[1] allowEOF:YES];
            if (err != TCL_OK) {
                return err;
            }
            NSString *encodingIdentifier = [NSString stringWithUTF8String:Tcl_GetStringFromObj(objv[2], NULL)];
            HFStringEncoding *encoding = [[HFEncodingManager shared] encodingByIdentifier:encodingIdentifier];
            if (!encoding) {
                Tcl_SetObjResult(_interp, Tcl_ObjPrintf("Unknown identifier %s", encodingIdentifier.UTF8String));
                return TCL_ERROR;
            }
            NSString *label = nil;
            if (objc == 4) {
                label = [NSString stringWithUTF8String:Tcl_GetStringFromObj(objv[3], NULL)];
            }
            NSString *str = [self readStringDataForSize:len encoding:encoding forLabel:label];
            if (!str) {
                Tcl_SetObjResult(_interp, Tcl_ObjPrintf("Failed to read %ld bytes", len));
                return TCL_ERROR;
            }
            Tcl_SetObjResult(_interp, Tcl_NewStringObj(str.UTF8String, -1));
            break;
        }
        case command_cstr: {
            if (objc != 2 && objc != 3) {
                Tcl_WrongNumArgs(_interp, 1, objv, "encoding [label]");
                return TCL_ERROR;
            }
            NSString *encodingIdentifier = [NSString stringWithUTF8String:Tcl_GetStringFromObj(objv[1], NULL)];
            HFStringEncoding *encoding = [[HFEncodingManager shared] encodingByIdentifier:encodingIdentifier];
            if (!encoding) {
                Tcl_SetObjResult(_interp, Tcl_ObjPrintf("Unknown identifier %s", encodingIdentifier.UTF8String));
                return TCL_ERROR;
            }
            NSString *label = nil;
            if (objc == 3) {
                label = [NSString stringWithUTF8String:Tcl_GetStringFromObj(objv[2], NULL)];
            }
            NSString *str = [self readCStringForEncoding:encoding forLabel:label];
            if (!str) {
                Tcl_SetObjResult(_interp, Tcl_ObjPrintf("Failed to read cstr"));
                return TCL_ERROR;
            }
            Tcl_SetObjResult(_interp, Tcl_NewStringObj(str.UTF8String, -1));
            break;
        }
        case command_move: {
            CHECK_SINGLE_ARG("len");
            long len;
            int err = Tcl_GetLongFromObj(_interp, objv[1], &len);
            if (err != TCL_OK) {
                return err;
            }
            [self moveTo:len];
            break;
        }
        case command_goto: {
            CHECK_SINGLE_ARG("offset");
            long offset;
            int err = Tcl_GetLongFromObj(_interp, objv[1], &offset);
            if (err != TCL_OK) {
                return err;
            }
            if (offset < 0) {
                // Negative number is offset from the end
                [self goTo:self.length - labs(offset)];
            } else {
                [self goTo:offset];
            }
            break;
        }
        case command_pos: {
            CHECK_NO_ARG;
            Tcl_SetObjResult(_interp, tcl_obj_from_uint64(self.position));
            break;
        }
        case command_len: {
            CHECK_NO_ARG;
            Tcl_SetObjResult(_interp, tcl_obj_from_uint64(self.length - self.anchor));
            break;
        }
        case command_end: {
            CHECK_NO_ARG;
            Tcl_SetObjResult(_interp, Tcl_NewBooleanObj(self.isEOF));
            break;
        }
        case command_include: {
            CHECK_SINGLE_ARG("relative_path")
            NSString *path = [NSString stringWithUTF8String:Tcl_GetStringFromObj(objv[1], NULL)];
            BOOL found = NO;
            for (NSString *folder in @[self.templatesFolder, self.bundleTemplatesPath]) {
                NSString *fullPath = [folder stringByAppendingPathComponent:path];
                if ([NSFileManager.defaultManager fileExistsAtPath:fullPath]) {
                    NSString *error = [self evaluateScript:fullPath];
                    if (error) {
                        Tcl_AddErrorInfo(_interp, error.UTF8String);
                        return TCL_ERROR;
                    }
                    NSLog(@"Include path \"%@\" found in %@", path, folder);
                    found = YES;
                    break;
                }
            }
            if (!found) {
                NSString *message = [NSString stringWithFormat:@"Include file not found: \"%@\"", path];
                Tcl_SetErrno(ENOENT);
                Tcl_AddErrorInfo(_interp, message.UTF8String);
                return TCL_ERROR;
            }
            break;
        }
        case command_hf_min_version_required: {
            CHECK_SINGLE_ARG("major[.minor[.patch]]");
            int major;
            int minor;
            int patch;
            if (![self parseVersionString:[NSString stringWithUTF8String:Tcl_GetString(objv[1])] major:&major minor:&minor patch:&patch]) {
                Tcl_SetErrno(EIO);
                Tcl_AddErrorInfo(_interp, "Could not parse minimum version information");
                return TCL_ERROR;
            }
            const long need_version = versionInteger(major, minor, patch);
            if ([self haveVersion] < need_version) {
                NSString *message = [NSString stringWithFormat:@"This build of Hex Fiend (v%s) does not meet this template's minimum requirement (v%d.%d.%d)",
                                        kVersionString, major, minor, patch];
                Tcl_SetErrno(EIO);
                Tcl_AddErrorInfo(_interp, message.UTF8String);
                return TCL_ERROR;
            }
            break;
        }
        case command_requires: {
            if (objc != 3) {
                Tcl_WrongNumArgs(_interp, 1, objv, "offset \"hex values\"");
                return TCL_ERROR;
            }
            long offset;
            int err = [self getOffset:&offset objv:objv[1]];
            if (err != TCL_OK) {
                return err;
            }
            NSString *hexvalues = [NSString stringWithUTF8String:Tcl_GetStringFromObj(objv[2], NULL)];
            if (![self requireDataAtOffset:offset toMatchHexValues:hexvalues]) {
                return TCL_ERROR;
            }
            break;
        }
        case command_section: {
            if (objc < 2 || objc > 4) {
                Tcl_WrongNumArgs(_interp, 1, objv, " [-collapsed] label [body]");
                return TCL_ERROR;
            }
            int labelArg = 1;
            if (0 == strcmp("-collapsed", Tcl_GetString(objv[labelArg]))) {
                labelArg++;
            }

            NSString *label = [NSString stringWithUTF8String:Tcl_GetString(objv[labelArg])];
            [self beginSectionWithLabel:label collapsed:(labelArg > 1)];
            if (objc == labelArg + 2) {
                const int err = Tcl_EvalObjEx(_interp, objv[labelArg + 1], 0);
                if (err != TCL_OK) {
                    return err;
                }
                NSString *error = nil;
                if (![self endSection:&error]) {
                    Tcl_SetObjResult(_interp, Tcl_NewStringObj(error.UTF8String, -1));
                    return TCL_ERROR;
                }
            }
            break;
        }
        case command_endsection: {
            CHECK_NO_ARG;
            NSString *error = nil;
            if (![self endSection:&error]) {
                Tcl_SetObjResult(_interp, Tcl_NewStringObj(error.UTF8String, -1));
                return TCL_ERROR;
            }
            break;
        }
        case command_sectionname: {
            CHECK_SINGLE_ARG("value")
            NSString *name = [NSString stringWithUTF8String:Tcl_GetStringFromObj(objv[1], NULL)];
            NSString *error = nil;
            if (![self setSectionName:name error:&error]) {
                Tcl_SetObjResult(_interp, Tcl_NewStringObj(error.UTF8String, -1));
                return TCL_ERROR;
            }
            break;
        }
        case command_sectionvalue: {
            CHECK_SINGLE_ARG("value")
            NSString *value = [NSString stringWithUTF8String:Tcl_GetStringFromObj(objv[1], NULL)];
            NSString *error = nil;
            if (![self setSectionValue:value error:&error]) {
                Tcl_SetObjResult(_interp, Tcl_NewStringObj(error.UTF8String, -1));
                return TCL_ERROR;
            }
            break;
        }
        case command_sectioncollapse: {
            CHECK_NO_ARG;
            NSString *error = nil;
            if (![self sectionCollapse:&error]) {
                Tcl_SetObjResult(_interp, Tcl_NewStringObj(error.UTF8String, -1));
                return TCL_ERROR;
            }
            break;
        }
        case command_zlib_uncompress: {
            CHECK_SINGLE_ARG("data")
            int numBytes = 0;
            const unsigned char *bytes = Tcl_GetByteArrayFromObj(objv[1], &numBytes);
            if (!bytes) {
                return TCL_ERROR;
            }
            int factor = 5;
            NSMutableData *data = nil;
            uLongf destLen = 0;
            for (int i = 0; i < 10; i++) {
                data = [NSMutableData dataWithLength:numBytes * factor];
                destLen = data.length;
                int res = uncompress(data.mutableBytes, &destLen, bytes, numBytes);
                if (res == Z_BUF_ERROR) {
                    factor *= 2;
                } else if (res == Z_OK) {
                    break;
                } else {
                    NSLog(@"Unknown zlib error %d", res);
                    return TCL_ERROR;
                }
            }
            Tcl_SetObjResult(_interp, Tcl_NewByteArrayObj((const unsigned char *)data.bytes, (int)destLen));
            break;
        }
        case command_entry: {
            if (objc < 3 || objc > 5) {
                Tcl_WrongNumArgs(_interp, 1, objv, "label value [length [offset]]");
                return TCL_ERROR;
            }
            NSString *label = [NSString stringWithUTF8String:Tcl_GetStringFromObj(objv[1], NULL)];
            NSString *value = [NSString stringWithUTF8String:Tcl_GetStringFromObj(objv[2], NULL)];
            unsigned long long length = 0;
            unsigned long long offset = 0;
            unsigned long long *lengthPtr = NULL;
            unsigned long long *offsetPtr = NULL;
            if (objc >= 4) {
                long len;
                int err = [self getLength:&len objv:objv[3] allowEOF:NO];
                if (err != TCL_OK) {
                    return err;
                }
                length = len;
                lengthPtr = &length;
            }
            if (objc == 5) {
                long off;
                int err = [self getOffset:&off objv:objv[4]];
                if (err != TCL_OK) {
                    return err;
                }
                offset = off;
                offsetPtr = &offset;
            }
            [self addEntryWithLabel:label value:value length:lengthPtr offset:offsetPtr];
            break;
        }
        case command_uint8_bits:
        case command_uint16_bits:
        case command_uint32_bits:
        case command_uint64_bits: {
            if (objc < 2 || objc > 3) {
                Tcl_WrongNumArgs(_interp, 1, objv, "bits [label]");
                return TCL_ERROR;
            }
            NSString *bits = [NSString stringWithUTF8String:Tcl_GetStringFromObj(objv[1], NULL)];
            NSString *label = nil;
            if (objc == 3) {
                label = [NSString stringWithUTF8String:Tcl_GetStringFromObj(objv[2], NULL)];
            }
            unsigned numBytes = 0;
            switch (command) {
                case command_uint8_bits: numBytes = 1; break;
                case command_uint16_bits: numBytes = 2; break;
                case command_uint32_bits: numBytes = 4; break;
                case command_uint64_bits: numBytes = 8; break;
                default:
                    Tcl_SetObjResult(_interp, Tcl_NewStringObj("This shouldn't happen.", -1));
                    return TCL_ERROR;
            }
            uint64_t val;
            NSString *error = nil;
            if (![self readBits:bits byteCount:numBytes forLabel:label result:&val error:&error]) {
                Tcl_SetObjResult(_interp, Tcl_NewStringObj(error.UTF8String, -1));
                return TCL_ERROR;
            }
            Tcl_SetObjResult(_interp, tcl_obj_from_uint64(val));
            return TCL_OK;
        }
        case command_uleb128: {
            if (objc > 2) {
                Tcl_WrongNumArgs(_interp, 1, objv, "[label]");
                return TCL_ERROR;
            }
            uint64_t val;
            NSString *label = nil;
            if (objc == 2) {
                label = [NSString stringWithUTF8String:Tcl_GetStringFromObj(objv[1], NULL)];
            }
            if (![self readULEB128:&val forLabel:label]) {
                Tcl_SetObjResult(_interp, Tcl_NewStringObj("Failed to read bytes", -1));
                return TCL_ERROR;
            }
            Tcl_SetObjResult(_interp, tcl_obj_from_uint64(val));
            break;
        }
        case command_sleb128: {
            if (objc > 2) {
                Tcl_WrongNumArgs(_interp, 1, objv, "[label]");
                return TCL_ERROR;
            }
            int64_t val;
            NSString *label = nil;
            if (objc == 2) {
                label = [NSString stringWithUTF8String:Tcl_GetStringFromObj(objv[1], NULL)];
            }
            if (![self readSLEB128:&val forLabel:label]) {
                Tcl_SetObjResult(_interp, Tcl_NewStringObj("Failed to read bytes", -1));
                return TCL_ERROR;
            }
            Tcl_SetObjResult(_interp, Tcl_NewWideIntObj((Tcl_WideInt)val));
            break;
        }
    }
    return TCL_OK;
}

- (int)runTypeCommand:(enum command)command objc:(int)objc objv:(struct Tcl_Obj * CONST *)objv {
    BOOL hexSwitchAllowed = NO;
    switch (command) {
        case command_uint32:
            hexSwitchAllowed = YES;
            break;
        default:
            break;
    }
    int asHexFlag = 0;
    NSString *label = nil;
    Tcl_Obj **extraArgs = NULL;
    Tcl_ArgvInfo argInfoTable[] = {
        {TCL_ARGV_CONSTANT, "-hex", (void*)1, &asHexFlag, "display as hexadecimal", NULL},
        TCL_ARGV_AUTO_HELP,
        TCL_ARGV_TABLE_END,
    };
    int err = Tcl_ParseArgsObjv(_interp, argInfoTable, &objc, objv, &extraArgs);
    if (err != TCL_OK) {
        return err;
    }
    const BOOL asHex = asHexFlag == 1;
    if (extraArgs && objc > 1) {
        for (int i = 1; i < objc; i++) {
            const char *arg = Tcl_GetStringFromObj(extraArgs[i], NULL);
            if (arg && arg[0] == '-') {
                Tcl_SetObjResult(_interp, Tcl_ObjPrintf("Unknown option %s", arg));
                ckfree((char *)extraArgs);
                return TCL_ERROR;
            }
        }
        if (objc > 2) {
            const char *usage = hexSwitchAllowed ? "[-hex] [label]" : "[label";
            Tcl_WrongNumArgs(_interp, 0, objv, usage);
            ckfree((char *)extraArgs);
            return TCL_ERROR;
        }
        label = [NSString stringWithUTF8String:Tcl_GetStringFromObj(extraArgs[1], NULL)];
    }
    if (objc > 0) {
        ckfree((char *)extraArgs);
    }
    switch (command) {
        case command_uint64: {
            uint64_t val;
            if (![self readUInt64:&val forLabel:label asHex:asHex == 1]) {
                Tcl_SetObjResult(_interp, Tcl_NewStringObj("Failed to read uint64 bytes", -1));
                return TCL_ERROR;
            }
            Tcl_SetObjResult(_interp, tcl_obj_from_uint64(val));
            break;
        }
        case command_int64: {
            int64_t val;
            if (![self readInt64:&val forLabel:label]) {
                Tcl_SetObjResult(_interp, Tcl_NewStringObj("Failed to read int64 bytes", -1));
                return TCL_ERROR;
            }
            Tcl_SetObjResult(_interp, Tcl_NewWideIntObj((Tcl_WideInt)val));
            break;
        }
        case command_uint32: {
            uint32_t val;
            if (![self readUInt32:&val forLabel:label asHex:asHex]) {
                Tcl_SetObjResult(_interp, Tcl_NewStringObj("Failed to read uint32 bytes", -1));
                return TCL_ERROR;
            }
            Tcl_SetObjResult(_interp, Tcl_NewWideIntObj((Tcl_WideInt)val));
            break;
        }
        case command_int32: {
            int32_t val;
            if (![self readInt32:&val forLabel:label]) {
                Tcl_SetObjResult(_interp, Tcl_NewStringObj("Failed to read int32 bytes", -1));
                return TCL_ERROR;
            }
            Tcl_SetObjResult(_interp, Tcl_NewIntObj((int)val));
            break;
        }
        case command_uint24: {
            uint32_t val;
            if (![self readUInt24:&val forLabel:label]) {
                Tcl_SetObjResult(_interp, Tcl_NewStringObj("Failed to read uint24 bytes", -1));
                return TCL_ERROR;
            }
            Tcl_SetObjResult(_interp, Tcl_NewWideIntObj((Tcl_WideInt)val));
            break;
        }
        case command_uint16: {
            uint16_t val;
            if (![self readUInt16:&val forLabel:label asHex:asHex]) {
                Tcl_SetObjResult(_interp, Tcl_NewStringObj("Failed to read uint16 bytes", -1));
                return TCL_ERROR;
            }
            Tcl_SetObjResult(_interp, Tcl_NewIntObj((int)val));
            break;
        }
        case command_int16: {
            int16_t val;
            if (![self readInt16:&val forLabel:label]) {
                Tcl_SetObjResult(_interp, Tcl_NewStringObj("Failed to read int16 bytes", -1));
                return TCL_ERROR;
            }
            Tcl_SetObjResult(_interp, Tcl_NewIntObj((int)val));
            break;
        }
        case command_uint8: {
            uint8_t val;
            if (![self readUInt8:&val forLabel:label asHex:asHex]) {
                Tcl_SetObjResult(_interp, Tcl_NewStringObj("Failed to read uint8 bytes", -1));
                return TCL_ERROR;
            }
            Tcl_SetObjResult(_interp, Tcl_NewIntObj((int)val));
            break;
        }
        case command_int8: {
            int8_t val;
            if (![self readInt8:&val forLabel:label]) {
                Tcl_SetObjResult(_interp, Tcl_NewStringObj("Failed to read int8 bytes", -1));
                return TCL_ERROR;
            }
            Tcl_SetObjResult(_interp, Tcl_NewIntObj((int)val));
            break;
        }
        case command_float: {
            float val;
            if (![self readFloat:&val forLabel:label]) {
                Tcl_SetObjResult(_interp, Tcl_NewStringObj("Failed to read float bytes", -1));
                return TCL_ERROR;
            }
            Tcl_SetObjResult(_interp, Tcl_NewDoubleObj(val));
            break;
        }
        case command_double: {
            double val;
            if (![self readDouble:&val forLabel:label]) {
                Tcl_SetObjResult(_interp, Tcl_NewStringObj("Failed to read double bytes", -1));
                return TCL_ERROR;
            }
            Tcl_SetObjResult(_interp, Tcl_NewDoubleObj(val));
            break;
        }
        case command_macdate: {
            NSDate *date = nil;
            if (![self readMacDate:&date forLabel:label]) {
                Tcl_SetObjResult(_interp, Tcl_NewStringObj("Failed to read macdate bytes", -1));
                return TCL_ERROR;
            }
            Tcl_SetObjResult(_interp, Tcl_NewDoubleObj(date.timeIntervalSince1970));
            break;
        }
        case command_fatdate: {
            NSString *dateErr = nil;
            NSString *date = [self readFatDateWithLabel:label error:&dateErr];
            if (!date) {
                Tcl_SetObjResult(_interp, Tcl_NewStringObj(dateErr.UTF8String, -1));
                return TCL_ERROR;
            }
            Tcl_SetObjResult(_interp, Tcl_NewStringObj(date.UTF8String, -1));
            break;
        }
        case command_fattime: {
            NSString *timeErr = nil;
            NSString *time = [self readFatTimeWithLabel:label error:&timeErr];
            if (!time) {
                Tcl_SetObjResult(_interp, Tcl_NewStringObj(timeErr.UTF8String, -1));
                return TCL_ERROR;
            }
            Tcl_SetObjResult(_interp, Tcl_NewStringObj(time.UTF8String, -1));
            break;
        }
        case command_unixtime32:
        case command_unixtime64: {
            const unsigned numBytes = command == command_unixtime32 ? 4 : 8;
            NSString *dateErr = nil;
            NSDate *date = [self readUnixTime:numBytes forLabel:label error:&dateErr];
            if (!date) {
                Tcl_SetObjResult(_interp, Tcl_NewStringObj(dateErr.UTF8String, -1));
                return TCL_ERROR;
            }
            Tcl_SetObjResult(_interp, Tcl_NewDoubleObj(date.timeIntervalSince1970));
            break;
        }
        case command_uuid: {
            NSUUID *uuid = nil;
            if (![self readUUID:&uuid forLabel:label]) {
                Tcl_SetObjResult(_interp, Tcl_NewStringObj("Failed to read uuid bytes", -1));
                return TCL_ERROR;
            }
            NSString *str = uuid.UUIDString;
            Tcl_SetObjResult(_interp, Tcl_NewStringObj(str.UTF8String, -1));
            break;
        }
        default:
            HFASSERT(0);
            break;
    }
    return TCL_OK;
}

@end
