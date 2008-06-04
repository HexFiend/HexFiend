//
//  HFPasteboardOwner.h
//  HexFiend_2
//
//  Created by Peter Ammon on 1/12/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class HFByteArray;

extern NSString *const HFPrivateByteArrayPboardType;

@interface HFPasteboardOwner : NSObject {
    @private
    HFByteArray *byteArray;
    NSPasteboard *pasteboard; //not retained
    NSUInteger bytesPerLine;
    
}

/* Creates an HFPasteboardOwner to own the given pasteboard with the given types.  Note that the NSPasteboard retains its owner. */
+ ownPasteboard:(NSPasteboard *)pboard forByteArray:(HFByteArray *)array withTypes:(NSArray *)types;
- (HFByteArray *)byteArray;

/* NSPasteboard delegate methods, declared here to indicate that subclasses should call super */
- (void)pasteboard:(NSPasteboard *)sender provideDataForType:(NSString *)type;
- (void)pasteboardChangedOwner:(NSPasteboard *)pboard;

/* Useful property that several pasteboard types want to know */
- (void)setBytesPerLine:(NSUInteger)bytesPerLine;
- (NSUInteger)bytesPerLine;

/* For efficiency, Hex Fiend writes pointers to HFByteArrays into pasteboards.  In the case that the user quits and relaunches Hex Fiend, we don't want to read a pointer from the old process, so each process we generate a UUID.  This is constant for the lifetime of the process. */
+ (NSString *)uuid;

/* Unpacks a byte array from a pasteboard, preferring HFPrivateByteArrayPboardType */
+ (HFByteArray *)unpackByteArrayFromPasteboard:(NSPasteboard *)pasteboard;

/* Used to handle the case where copying data will require a lot of memory and give the user a chance to confirm. */
- (unsigned long long)amountToCopyForDataLength:(unsigned long long)numBytes stringLength:(unsigned long long)stringLength;

@end
