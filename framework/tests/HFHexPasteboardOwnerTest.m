//
//  HFHexPasteboardOwnerTest.m
//  HexFiend_2
//
//  Created by Kevin Wojniak on 7/15/17.
//  Copyright © 2017 ridiculous_fish. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <HexFiend/HexFiend.h>
#import <HexFiend/HFHexPasteboardOwner.h>
#import <zlib.h>

@interface HFHexPasteboardOwnerTest : XCTestCase

@end

@implementation HFHexPasteboardOwnerTest

- (NSString *)stringForData:(NSMutableData *)data bytesPerColumn:(NSUInteger)bytesPerColumn {
    HFSharedMemoryByteSlice *slice = [[HFSharedMemoryByteSlice alloc] initWithData:data];
    HFBTreeByteArray *byteArray = [[HFBTreeByteArray alloc] initWithByteSlice:slice];
    HFHexPasteboardOwner *owner = [HFHexPasteboardOwner ownPasteboard:[NSPasteboard generalPasteboard] forByteArray:byteArray withTypes:@[HFPrivateByteArrayPboardType, NSPasteboardTypeString]];
    owner.bytesPerColumn = bytesPerColumn;
    HFProgressTracker *tracker = [[HFProgressTracker alloc] init];
    return [owner stringFromByteArray:byteArray ofLength:byteArray.length trackingProgress:tracker];
}

- (NSString *)stringForBytes:(unsigned char *)bytes length:(NSUInteger)length bytesPerColumn:(NSUInteger)bytesPerColumn {
    NSMutableData *data = [NSMutableData dataWithBytesNoCopy:bytes length:length freeWhenDone:NO];
    return [self stringForData:data bytesPerColumn:bytesPerColumn];
}

- (void)testEmpty {
    NSMutableData *data = [NSMutableData data];
    XCTAssertEqualObjects([self stringForData:data bytesPerColumn:0], @"");
}

- (void)test1Byte {
    unsigned char bytes[1] = {0x00};
    XCTAssertEqualObjects([self stringForBytes:bytes length:sizeof(bytes) bytesPerColumn:0], @"00");
}

- (void)test4Bytes {
    unsigned char bytes[4] = {0x00, 0x11, 0x22, 0x33};
    XCTAssertEqualObjects([self stringForBytes:bytes length:sizeof(bytes) bytesPerColumn:0], @"00112233");
}

- (void)test6Bytes {
    unsigned char bytes[6] = {0x00, 0x11, 0x22, 0x33, 0x44, 0x55};
    XCTAssertEqualObjects([self stringForBytes:bytes length:sizeof(bytes) bytesPerColumn:0], @"001122334455");
}

- (void)test10Bytes {
    unsigned char bytes[10] = {0x00, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88, 0x99};
    XCTAssertEqualObjects([self stringForBytes:bytes length:sizeof(bytes) bytesPerColumn:0], @"00112233445566778899");
}

- (void)testEmptyColumns {
    NSMutableData *data = [NSMutableData data];
    XCTAssertEqualObjects([self stringForData:data bytesPerColumn:4], @"");
}

- (void)test1ByteColumns {
    unsigned char bytes[1] = {0x00};
    XCTAssertEqualObjects([self stringForBytes:bytes length:sizeof(bytes) bytesPerColumn:4], @"00");
}

- (void)test4BytesColumns {
    unsigned char bytes[4] = {0x00, 0x11, 0x22, 0x33};
    XCTAssertEqualObjects([self stringForBytes:bytes length:sizeof(bytes) bytesPerColumn:4], @"00112233");
}

- (void)test6BytesColumns {
    unsigned char bytes[6] = {0x00, 0x11, 0x22, 0x33, 0x44, 0x55};
    XCTAssertEqualObjects([self stringForBytes:bytes length:sizeof(bytes) bytesPerColumn:4], @"00112233 4455");
}

- (void)test10BytesColumns {
    unsigned char bytes[10] = {0x00, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88, 0x99};
    XCTAssertEqualObjects([self stringForBytes:bytes length:sizeof(bytes) bytesPerColumn:4], @"00112233 44556677 8899");
}

- (NSMutableData *)dataForBundleGZFile:(NSString *)filename {
    NSString *path = [[NSBundle bundleForClass:[self class]] pathForResource:filename ofType:nil];
    HFASSERT(path != nil);
    gzFile file = gzopen(path.fileSystemRepresentation, "r");
    HFASSERT(file != NULL);
    char buf[4096];
    NSMutableData *data = [NSMutableData data];
    for (;;) {
        const int bytesRead = gzread(file, buf, sizeof(buf));
        HFASSERT(bytesRead >= 0);
        int errnum = 0;
        gzerror(file, &errnum);
        HFASSERT(errnum == Z_OK);
        if (bytesRead <= 0) {
            break;
        }
        [data appendBytes:buf length:bytesRead];
    }
    HFASSERT(gzclose(file) == Z_OK);
    return data;
}

- (NSString *)stringForBundleGZFile:(NSString *)filename {
    return [[NSString alloc] initWithData:[self dataForBundleGZFile:filename] encoding:NSUTF8StringEncoding];
}

- (void)testBig {
    NSMutableData *data = [NSMutableData dataWithLength:64 * 1024];
    XCTAssertEqualObjects([self stringForData:data bytesPerColumn:0], [self stringForBundleGZFile:@"BigResult.txt.gz"]);
}

- (void)testBigColumns {
    NSMutableData *data = [NSMutableData dataWithLength:64 * 1024];
    XCTAssertEqualObjects([self stringForData:data bytesPerColumn:4], [self stringForBundleGZFile:@"BigColumnsResult.txt.gz"]);
}

@end
