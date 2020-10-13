//
//  HFTestHashing.m
//  HexFiend_2
//
//  Copyright 2008 ridiculous_fish. All rights reserved.
//

#import "HFTestHashing.h"
#import <HexFiend/HexFiend.h>
#include <CommonCrypto/CommonDigest.h>

NSData *HFHashFile(NSURL *url) {
    NSMutableData *data = [NSMutableData dataWithLength:CC_SHA1_DIGEST_LENGTH];
    CC_SHA1_CTX ctx;
    CC_SHA1_Init(&ctx);
    
    REQUIRE_NOT_NULL(url);
    HFASSERT([url isFileURL]);
    const CC_LONG bufferSize = 1024 * 1024 * 4;
    unsigned char *buffer = malloc(bufferSize);
    CC_LONG amount;
    NSInputStream *stream = [[NSInputStream alloc] initWithFileAtPath:[url path]];
    [stream open];
    while ((amount = (CC_LONG)[stream read:buffer maxLength:bufferSize]) > 0) {
        CC_SHA1_Update(&ctx, buffer, amount);
    }
    [stream close];
    CC_SHA1_Final([data mutableBytes], &ctx);
    free(buffer);
    return data;
}

NSData *HFHashByteArray(HFByteArray *array) {
    REQUIRE_NOT_NULL(array);
    NSMutableData *data = [NSMutableData dataWithLength:CC_SHA1_DIGEST_LENGTH];
    CC_SHA1_CTX ctx;
    CC_SHA1_Init(&ctx);
    
    const CC_LONG bufferSize = 1024 * 1024 * 4;
    unsigned char *buffer = malloc(bufferSize);
    unsigned long long offset = 0, length = [array length];
    while (offset < length) {
        CC_LONG amount = bufferSize;
        if (amount > (length - offset)) amount = (CC_LONG)ll2l(length - offset);
        [array copyBytes:buffer range:HFRangeMake(offset, amount)];
        CC_SHA1_Update(&ctx, buffer, amount);
        offset += amount;
    }
    CC_SHA1_Final([data mutableBytes], &ctx);
    free(buffer);
    return data;
}
