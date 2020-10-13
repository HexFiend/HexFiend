//
//  HFStringEncoding.m
//  HexFiend_Framework
//
//  Created by Kevin Wojniak on 6/16/18.
//  Copyright © 2018 ridiculous_fish. All rights reserved.
//

#import <HexFiend/HFFrameworkPrefix.h>
#import <HexFiend/HFAssert.h>
#import "HFStringEncoding.h"

@implementation HFStringEncoding

- (BOOL)isASCII {
    return NO;
}

- (NSString *)stringFromBytes:(const unsigned char * __unused)bytes length:(NSUInteger __unused)length {
    HFASSERT(0);
    @throw [NSException exceptionWithName:NSGenericException reason:@"Unimplemented" userInfo:nil];
}

- (NSData *)dataFromString:(NSString * __unused)string {
    HFASSERT(0);
    @throw [NSException exceptionWithName:NSGenericException reason:@"Unimplemented" userInfo:nil];
}

- (void)encodeWithCoder:(NSCoder * __unused)coder {
    @throw [NSException exceptionWithName:NSGenericException reason:@"Unimplemented" userInfo:nil];
}

- (nullable instancetype)initWithCoder:(NSCoder * __unused)coder {
    @throw [NSException exceptionWithName:NSGenericException reason:@"Unimplemented" userInfo:nil];
}

- (NSComparisonResult)compare:(HFStringEncoding *)other {
    return [self.name compare:other.name];
}

@end
