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
};

@interface HFTclTemplateController ()

@property (weak) HFController *controller;
@property unsigned long long position;
@property HFTemplateNode *root;
@property (weak) HFTemplateNode *currentNode;

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
    const struct command commands[] = {
        {"uint64", cmd_uint64},
        {"int64", cmd_int64},
        {"uint32", cmd_uint32},
        {"int32", cmd_int32},
        {"uint16", cmd_uint16},
        {"int16", cmd_int16},
        {"uint8", cmd_uint8},
        {"byte", cmd_uint8},
        {"int8", cmd_int8},
    };
    for (size_t i = 0; i < sizeof(commands) / sizeof(commands[0]); ++i) {
        Tcl_CreateObjCommand(_interp, commands[i].name, commands[i].proc, (__bridge ClientData)self, NULL);
    }

    return self;
}

- (void)dealloc {
    if (_interp) {
        Tcl_DeleteInterp(_interp);
    }
}

- (HFTemplateNode *)evaluateScript:(NSString *)path forController:(HFController *)controller error:(NSString **)error {
    self.controller = controller;
    self.position = 0;
    self.root = [[HFTemplateNode alloc] init];
    self.root.isGroup = YES;
    self.currentNode = self.root;
    if (Tcl_EvalFile(_interp, [path fileSystemRepresentation]) != TCL_OK) {
        if (error) {
            *error = [NSString stringWithUTF8String:Tcl_GetStringResult(_interp)];
        }
        return nil;
    }
    if (error) {
        *error = nil;
    }
    return self.root;
}

- (int)runCommand:(enum command)command objc:(int)objc objv:(struct Tcl_Obj * CONST *)objv {
    if (objc != 2) {
        Tcl_WrongNumArgs(_interp, 1, objv, "title");
        return TCL_ERROR;
    }
    NSString *name = [NSString stringWithUTF8String:Tcl_GetStringFromObj(objv[1], NULL)];
    switch (command) {
        case command_uint64: {
            uint64_t val;
            if (![self readBytes:&val size:sizeof(val)]) {
                break;
            }
            Tcl_SetObjResult(_interp, tcl_obj_from_uint64(val));
            [self.currentNode.children addObject:[[HFTemplateNode alloc] initWithLabel:name value:[NSString stringWithFormat:@"%llu", val]]];
            break;
        }
        case command_int64: {
            int64_t val;
            if (![self readBytes:&val size:sizeof(val)]) {
                break;
            }
            Tcl_SetObjResult(_interp, tcl_obj_from_int64(val));
            [self.currentNode.children addObject:[[HFTemplateNode alloc] initWithLabel:name value:[NSString stringWithFormat:@"%lld", val]]];
            break;
        }
        case command_uint32: {
            uint32_t val;
            if (![self readBytes:&val size:sizeof(val)]) {
                break;
            }
            Tcl_SetObjResult(_interp, tcl_obj_from_uint32(val));
            [self.currentNode.children addObject:[[HFTemplateNode alloc] initWithLabel:name value:[NSString stringWithFormat:@"%u", val]]];
            break;
        }
        case command_int32: {
            int32_t val;
            if (![self readBytes:&val size:sizeof(val)]) {
                break;
            }
            Tcl_SetObjResult(_interp, tcl_obj_from_int32(val));
            [self.currentNode.children addObject:[[HFTemplateNode alloc] initWithLabel:name value:[NSString stringWithFormat:@"%d", val]]];
            break;
        }
        case command_uint16: {
            uint16_t val;
            if (![self readBytes:&val size:sizeof(val)]) {
                break;
            }
            Tcl_SetObjResult(_interp, tcl_obj_from_uint16(val));
            [self.currentNode.children addObject:[[HFTemplateNode alloc] initWithLabel:name value:[NSString stringWithFormat:@"%d", val]]];
            break;
        }
        case command_int16: {
            int16_t val;
            if (![self readBytes:&val size:sizeof(val)]) {
                break;
            }
            Tcl_SetObjResult(_interp, tcl_obj_from_int16(val));
            [self.currentNode.children addObject:[[HFTemplateNode alloc] initWithLabel:name value:[NSString stringWithFormat:@"%d", val]]];
            break;
        }
        case command_uint8: {
            uint8_t val;
            if (![self readBytes:&val size:sizeof(val)]) {
                break;
            }
            Tcl_SetObjResult(_interp, tcl_obj_from_uint8(val));
            [self.currentNode.children addObject:[[HFTemplateNode alloc] initWithLabel:name value:[NSString stringWithFormat:@"%d", val]]];
            break;
        }
        case command_int8: {
            int8_t val;
            if (![self readBytes:&val size:sizeof(val)]) {
                break;
            }
            Tcl_SetObjResult(_interp, tcl_obj_from_int8(val));
            [self.currentNode.children addObject:[[HFTemplateNode alloc] initWithLabel:name value:[NSString stringWithFormat:@"%d", val]]];
            break;
        }
    }
    return TCL_OK;
}

- (BOOL)readBytes:(void *)buffer size:(size_t)size {
    const HFRange range = HFRangeMake(self.controller.minimumSelectionLocation + self.position, size);
    if (!HFRangeIsSubrangeOfRange(range, HFRangeMake(0, self.controller.contentsLength))) {
        memset(buffer, 0, size);
        return NO;
    }
    [self.controller copyBytes:buffer range:range];
    self.position += size;
    return YES;
}

@end
