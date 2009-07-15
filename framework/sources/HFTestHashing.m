//
//  HFTestHashing.m
//  HexFiend_2
//
//  Created by Peter Ammon on 3/13/08.
//  Copyright 2008 ridiculous_fish. All rights reserved.
//

#if ! NDEBUG

#import <HexFiend/HFTestHashing.h>
#import <HexFiend/HFByteArray.h>
#include <openssl/sha.h>

NSData *HFHashFile(NSURL *url) {
    NSMutableData *data = [NSMutableData dataWithLength:SHA_DIGEST_LENGTH];
    SHA_CTX ctx;
    memset(&ctx, 0, sizeof ctx);
    SHA1_Init(&ctx);
    
    REQUIRE_NOT_NULL(url);
    HFASSERT([url isFileURL]);
    const NSUInteger bufferSize = 1024 * 1024 * 4;
    unsigned char *buffer = malloc(bufferSize);
    NSInteger amount;
    NSInputStream *stream = [[[NSInputStream alloc] initWithFileAtPath:[url path]] autorelease];
    [stream open];
    while ((amount = [stream read:buffer maxLength:bufferSize]) > 0) {
	SHA1_Update(&ctx, buffer, amount);
    }
    [stream close];
    SHA1_Final([data mutableBytes], &ctx);
    free(buffer);
    return data;
}

NSData *HFHashByteArray(HFByteArray *array) {
    REQUIRE_NOT_NULL(array);
    NSMutableData *data = [NSMutableData dataWithLength:SHA_DIGEST_LENGTH];
    SHA_CTX ctx;
    memset(&ctx, 0, sizeof ctx);
    SHA1_Init(&ctx);
    
    const NSUInteger bufferSize = 1024 * 1024 * 4;
    unsigned char *buffer = malloc(bufferSize);
    unsigned long long offset = 0, length = [array length];
    while (offset < length) {
	NSUInteger amount = bufferSize;
	if (amount > (length - offset)) amount = ll2l(length - offset);
	[array copyBytes:buffer range:HFRangeMake(offset, amount)];
	SHA1_Update(&ctx, buffer, amount);
	offset += amount;
    }
    SHA1_Final([data mutableBytes], &ctx);
    free(buffer);
    return data;
}


#endif
