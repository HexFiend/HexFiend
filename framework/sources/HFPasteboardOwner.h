//
//  HFPasteboardOwner.h
//  HexFiend_2
//
//  Copyright 2008 ridiculous_fish. All rights reserved.
//

#import <HexFiend/HFFrameworkPrefix.h>

NS_ASSUME_NONNULL_BEGIN

@class HFByteArray, HFProgressTracker;

extern NSString *const HFPrivateByteArrayPboardType;

@interface HFPasteboardOwner : NSObject {
    @private
    HFByteArray *byteArray;
    NSPasteboard *pasteboard; //not retained
    IBOutlet NSWindow *progressTrackingWindow;
    IBOutlet NSProgressIndicator *progressTrackingIndicator;
    IBOutlet NSTextField *progressTrackingDescriptionTextField;
    HFProgressTracker *progressTracker;
    unsigned long long dataAmountToCopy;
    NSUInteger bytesPerLine;
    BOOL retainedSelfOnBehalfOfPboard;
    BOOL backgroundCopyOperationFinished;
    BOOL didStartModalSessionForBackgroundCopyOperation;
    NSString *byteArrayMapKey;
}

/* Creates an HFPasteboardOwner to own the given pasteboard with the given types.  Note that the NSPasteboard retains its owner. */
+ (instancetype)ownPasteboard:(NSPasteboard *)pboard forByteArray:(HFByteArray *)array withTypes:(NSArray *)types;
- (HFByteArray *)byteArray;

/* Performs a copy to pasteboard with progress reporting. This must be overridden if you support types other than the private pboard type. */
- (void)writeDataInBackgroundToPasteboard:(NSPasteboard *)pboard ofLength:(unsigned long long)length forType:(NSString *)type trackingProgress:(nullable HFProgressTracker *)tracker;

/* NSPasteboard delegate methods, declared here to indicate that subclasses should call super */
- (void)pasteboard:(NSPasteboard *)sender provideDataForType:(NSString *)type;
- (void)pasteboardChangedOwner:(NSPasteboard *)pboard;

/* Useful property that several pasteboard types want to know */
@property (nonatomic) NSUInteger bytesPerLine;

/* For efficiency, Hex Fiend writes pointers to HFByteArrays into pasteboards.  In the case that the user quits and relaunches Hex Fiend, we don't want to read a pointer from the old process, so each process we generate a UUID.  This is constant for the lifetime of the process. */
+ (NSString *)uuid;

/* Unpacks a byte array from a pasteboard, preferring HFPrivateByteArrayPboardType */
+ (nullable HFByteArray *)unpackByteArrayFromPasteboard:(NSPasteboard *)pasteboard;

/* Used to handle the case where copying data will require a lot of memory and give the user a chance to confirm. */
- (unsigned long long)amountToCopyForDataLength:(unsigned long long)numBytes stringLength:(unsigned long long)stringLength;

/* Must be overridden to return the length of a string containing this number of bytes. */
- (unsigned long long)stringLengthForDataLength:(unsigned long long)dataLength;

@end

NS_ASSUME_NONNULL_END
