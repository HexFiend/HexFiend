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
#import "HFFunctions_Private.h"

static Tcl_Obj* tcl_obj_from_uint64(uint64_t value) {
    char buf[21];
    const size_t num_bytes = snprintf(buf, sizeof(buf), "%" PRIu64, value);
    return Tcl_NewStringObj(buf, (int)num_bytes);
}

static Tcl_Obj* tcl_obj_from_int64(int64_t value) {
    return Tcl_NewWideIntObj((Tcl_WideInt)value);
}

static Tcl_Obj* tcl_obj_from_uint32(uint32_t value) {
    return Tcl_NewWideIntObj((Tcl_WideInt)value);
}

static Tcl_Obj* tcl_obj_from_int32(int32_t value) {
    return Tcl_NewIntObj((int)value);
}

static Tcl_Obj* tcl_obj_from_uint16(uint16_t value) {
    return Tcl_NewIntObj((int)value);
}

static Tcl_Obj* tcl_obj_from_int16(int16_t value) {
    return Tcl_NewIntObj((int)value);
}

static Tcl_Obj* tcl_obj_from_uint8(uint8_t value) {
    return Tcl_NewIntObj((int)value);
}

static Tcl_Obj* tcl_obj_from_int8(int8_t value) {
    return Tcl_NewIntObj((int)value);
}

enum command {
    command_uint64,
    command_int64,
    command_uint32,
    command_int32,
    command_uint16,
    command_int16,
    command_uint8,
    command_int8,
    command_big_endian,
    command_little_endian,
    command_float,
    command_double,
    command_hex,
    command_ascii,
    command_move,
    command_end,
    command_requires,
};

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
DEFINE_COMMAND(uint16)
DEFINE_COMMAND(int16)
DEFINE_COMMAND(uint8)
DEFINE_COMMAND(int8)
DEFINE_COMMAND(float)
DEFINE_COMMAND(double)
DEFINE_COMMAND(big_endian)
DEFINE_COMMAND(little_endian)
DEFINE_COMMAND(hex)
DEFINE_COMMAND(ascii)
DEFINE_COMMAND(move)
DEFINE_COMMAND(end)
DEFINE_COMMAND(requires)

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
        CMD(uint16),
        CMD(int16),
        CMD(uint8),
        CMD_NAMED("byte", uint8),
        CMD(int8),
        CMD(float),
        CMD(double),
        CMD(big_endian),
        CMD(little_endian),
        CMD(hex),
        CMD(ascii),
        CMD(move),
        CMD(end),
        CMD(requires),
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

- (void)evaluateScript:(NSString *)path error:(NSString **)error {
    Tcl_LimitTypeSet(_interp, TCL_LIMIT_TIME);
    Tcl_Time time;
    Tcl_GetTime(&time);
    time.sec += 2;
    Tcl_LimitSetTime(_interp, &time);
    const int err = Tcl_EvalFile(_interp, [path fileSystemRepresentation]);
    if (err != TCL_OK) {
        if (error) {
            Tcl_Obj *options = Tcl_GetReturnOptions(_interp, err);
            Tcl_Obj *key = Tcl_NewStringObj("-errorinfo", -1);
            Tcl_Obj *value = NULL;
            Tcl_IncrRefCount(key);
            Tcl_DictObjGet(NULL, options, key, &value);
            Tcl_DecrRefCount(key);
            if (value) {
                *error = [NSString stringWithUTF8String:Tcl_GetStringFromObj(value, NULL)];
            }
        }
    }
}

#define CHECK_SINGLE_ARG \
    if (objc != 1) { \
        Tcl_WrongNumArgs(_interp, 0, objv, NULL); \
        return TCL_ERROR; \
    }

- (int)runCommand:(enum command)command objc:(int)objc objv:(struct Tcl_Obj * CONST *)objv {
    switch (command) {
        case command_uint64:
        case command_int64:
        case command_uint32:
        case command_int32:
        case command_uint16:
        case command_int16:
        case command_uint8:
        case command_int8:
        case command_float:
        case command_double:
            return [self runTypeCommand:command objc:objc objv:objv];
        case command_big_endian: {
            CHECK_SINGLE_ARG
            self.endian = HFEndianBig;
            break;
        }
        case command_little_endian: {
            CHECK_SINGLE_ARG
            self.endian = HFEndianLittle;
            break;
        }
        case command_hex:
        case command_ascii: {
            if (objc != 3) {
                Tcl_WrongNumArgs(_interp, 1, objv, "len label");
                return TCL_ERROR;
            }
            long len;
            int err = Tcl_GetLongFromObj(_interp, objv[1], &len);
            if (err != TCL_OK) {
                return err;
            }
            if (len <= 0) {
                Tcl_SetObjResult(_interp, Tcl_NewStringObj("Length must be greater than 0.", -1));
                return TCL_ERROR;
            }
            NSString *label = [NSString stringWithUTF8String:Tcl_GetStringFromObj(objv[2], NULL)];
            NSData *data = [self readDataForSize:len];
            if (!data) {
                Tcl_SetObjResult(_interp, Tcl_NewStringObj("Failed to read bytes", -1));
                return TCL_ERROR;
            }
            NSString *str = nil;
            switch (command) {
                case command_hex:
                    str = HFHexStringFromData(data);
                    Tcl_SetObjResult(_interp, Tcl_NewByteArrayObj(data.bytes, (int)data.length));
                    break;
                case command_ascii:
                    str = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
                    Tcl_SetObjResult(_interp, Tcl_NewStringObj(str.UTF8String, -1));
                    break;
                default:
                    HFASSERT(0);
                    break;
            }
            [self.currentNode.children addObject:[[HFTemplateNode alloc] initWithLabel:label value:str]];
            break;
        }
        case command_move: {
            if (objc != 2) {
                Tcl_WrongNumArgs(_interp, 0, objv, "len");
                return TCL_ERROR;
            }
            long len;
            int err = Tcl_GetLongFromObj(_interp, objv[1], &len);
            if (err != TCL_OK) {
                return err;
            }
            [self moveTo:len];
            break;
        }
        case command_end: {
            if (objc != 1) {
                Tcl_WrongNumArgs(_interp, 0, objv, NULL);
                return TCL_ERROR;
            }
            Tcl_SetObjResult(_interp, Tcl_NewBooleanObj(self.isEOF));
            break;
        }
        case command_requires: {
            if (objc != 3) {
                Tcl_WrongNumArgs(_interp, 1, objv, "offset \"hex values\"");
                return TCL_ERROR;
            }
            long offset;
            int err = Tcl_GetLongFromObj(_interp, objv[1], &offset);
            if (err != TCL_OK) {
                return err;
            }
            if (offset < 0) {
                Tcl_SetObjResult(_interp, Tcl_NewStringObj("Offset must be >= 0.", -1));
                return TCL_ERROR;
            }
            NSString *hexvalues = [NSString stringWithUTF8String:Tcl_GetStringFromObj(objv[2], NULL)];
            if (![self requireDataAtOffset:offset toMatchHexValues:hexvalues]) {
                return TCL_ERROR;
            }
            break;
        }
    }
    return TCL_OK;
}

- (int)runTypeCommand:(enum command)command objc:(int)objc objv:(struct Tcl_Obj * CONST *)objv {
    if (objc != 2) {
        Tcl_WrongNumArgs(_interp, 1, objv, "label");
        return TCL_ERROR;
    }
    NSString *label = [NSString stringWithUTF8String:Tcl_GetStringFromObj(objv[1], NULL)];
    switch (command) {
        case command_uint64: {
            uint64_t val;
            if (![self readUInt64:&val forLabel:label]) {
                Tcl_SetObjResult(_interp, Tcl_NewStringObj("Failed to read bytes", -1));
                return TCL_ERROR;
            }
            Tcl_SetObjResult(_interp, tcl_obj_from_uint64(val));
            break;
        }
        case command_int64: {
            int64_t val;
            if (![self readInt64:&val forLabel:label]) {
                Tcl_SetObjResult(_interp, Tcl_NewStringObj("Failed to read bytes", -1));
                return TCL_ERROR;
            }
            Tcl_SetObjResult(_interp, tcl_obj_from_int64(val));
            break;
        }
        case command_uint32: {
            uint32_t val;
            if (![self readUInt32:&val forLabel:label]) {
                Tcl_SetObjResult(_interp, Tcl_NewStringObj("Failed to read bytes", -1));
                return TCL_ERROR;
            }
            Tcl_SetObjResult(_interp, tcl_obj_from_uint32(val));
            break;
        }
        case command_int32: {
            int32_t val;
            if (![self readInt32:&val forLabel:label]) {
                Tcl_SetObjResult(_interp, Tcl_NewStringObj("Failed to read bytes", -1));
                return TCL_ERROR;
            }
            Tcl_SetObjResult(_interp, tcl_obj_from_int32(val));
            break;
        }
        case command_uint16: {
            uint16_t val;
            if (![self readUInt16:&val forLabel:label]) {
                Tcl_SetObjResult(_interp, Tcl_NewStringObj("Failed to read bytes", -1));
                return TCL_ERROR;
            }
            Tcl_SetObjResult(_interp, tcl_obj_from_uint16(val));
            break;
        }
        case command_int16: {
            int16_t val;
            if (![self readInt16:&val forLabel:label]) {
                Tcl_SetObjResult(_interp, Tcl_NewStringObj("Failed to read bytes", -1));
                return TCL_ERROR;
            }
            Tcl_SetObjResult(_interp, tcl_obj_from_int16(val));
            break;
        }
        case command_uint8: {
            uint8_t val;
            if (![self readUInt8:&val forLabel:label]) {
                Tcl_SetObjResult(_interp, Tcl_NewStringObj("Failed to read bytes", -1));
                return TCL_ERROR;
            }
            Tcl_SetObjResult(_interp, tcl_obj_from_uint8(val));
            break;
        }
        case command_int8: {
            int8_t val;
            if (![self readInt8:&val forLabel:label]) {
                Tcl_SetObjResult(_interp, Tcl_NewStringObj("Failed to read bytes", -1));
                return TCL_ERROR;
            }
            Tcl_SetObjResult(_interp, tcl_obj_from_int8(val));
            break;
        }
        case command_float: {
            float val;
            if (![self readFloat:&val forLabel:label]) {
                Tcl_SetObjResult(_interp, Tcl_NewStringObj("Failed to read bytes", -1));
                return TCL_ERROR;
            }
            Tcl_SetObjResult(_interp, Tcl_NewDoubleObj(val));
            break;
        }
        case command_double: {
            double val;
            if (![self readDouble:&val forLabel:label]) {
                Tcl_SetObjResult(_interp, Tcl_NewStringObj("Failed to read bytes", -1));
                return TCL_ERROR;
            }
            Tcl_SetObjResult(_interp, Tcl_NewDoubleObj(val));
            break;
        }
        default:
            HFASSERT(0);
            break;
    }
    return TCL_OK;
}

@end
