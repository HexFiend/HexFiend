//
//  HFPasteboardOwner.m
//  HexFiend_2
//
//  Copyright 2008 ridiculous_fish. All rights reserved.
//

#import <HexFiend/HFPasteboardOwner.h>
#import <HexFiend/HFProgressTracker.h>
#import <HexFiend/HFController.h>
#import <HexFiend/HFByteArray.h>
#import <HexFiend/HFFunctions.h>
#import <HexFiend/HFAssert.h>

//What's the smallest clipboard data size we should offer to avoid copying when quitting?  This is 5 MB
#define MINIMUM_PASTEBOARD_SIZE_TO_WARN_ABOUT (5UL << 20)

//What's the largest clipboard data size we should support exporting (at all?)  This is 500 MB.  Note that we can still copy more data than this internally, we just can't put it in, say, TextEdit.
#define MAXIMUM_PASTEBOARD_SIZE_TO_EXPORT (500UL << 20)

NSString *const HFPrivateByteArrayPboardType = @"HFPrivateByteArrayPboardType";

static NSMapTable *byteArrayMap = nil;

@implementation HFPasteboardOwner

+ (void)initialize {
    if (self == [HFPasteboardOwner class]) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(prepareCommonPasteboardsForChangeInFileNotification:) name:HFPrepareForChangeInFileNotification object:nil];

        HFASSERT_MAIN_THREAD(); // byteArrayMap is not thread safe
        byteArrayMap = [NSMapTable strongToWeakObjectsMapTable];
    }
}

- (instancetype)initWithPasteboard:(NSPasteboard *)pboard forByteArray:(HFByteArray *)array withTypes:(NSArray *)types {
    REQUIRE_NOT_NULL(pboard);
    REQUIRE_NOT_NULL(array);
    REQUIRE_NOT_NULL(types);
    self = [super init];
    byteArray = array;
    pasteboard = pboard;
    [pasteboard declareTypes:types owner:self];
    
    // get notified when we're about to write a file, so that if they're overwriting a file backing part of our byte array, we can properly clear or preserve our pasteboard
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(changeInFileNotification:) name:HFPrepareForChangeInFileNotification object:nil];
    
    // No background copies in progress when we start.
    progressTracker = nil;
    progressTrackingWindow = nil;

    HFASSERT_MAIN_THREAD(); // byteArrayMap is not thread safe
    byteArrayMapKey = [[self class] createUUI];
    HFASSERT([byteArrayMap objectForKey:byteArrayMapKey] == nil);
    [byteArrayMap setObject:byteArray forKey:byteArrayMapKey];
    
    return self;
}

+ (instancetype)ownPasteboard:(NSPasteboard *)pboard forByteArray:(HFByteArray *)array withTypes:(NSArray *)types {
    return [[self alloc] initWithPasteboard:pboard forByteArray:array withTypes:types];
}

- (void)tearDownPasteboardReferenceIfExists {
    if (pasteboard) {
        pasteboard = nil;
        [[NSNotificationCenter defaultCenter] removeObserver:self name:HFPrepareForChangeInFileNotification object:nil];
    }
    if (retainedSelfOnBehalfOfPboard) {
        CFRelease((CFTypeRef)self);
        retainedSelfOnBehalfOfPboard = NO;
    }
}

+ (HFByteArray *)_unpackByteArrayFromDictionary:(NSDictionary *)byteArrayDictionary {
    HFByteArray *result = nil;
    if (byteArrayDictionary) {
        NSString *uuid = byteArrayDictionary[@"HFUUID"];
        if ([uuid isEqual:[self uuid]]) {
            HFASSERT_MAIN_THREAD(); // byteArrayMap is not thread safe
            result = [byteArrayMap objectForKey:byteArrayDictionary[@"HFByteArray"]];
        }
    }
    return result;
}

+ (HFByteArray *)unpackByteArrayFromPasteboard:(NSPasteboard *)pasteboard {
    REQUIRE_NOT_NULL(pasteboard);
    HFByteArray *result = [self _unpackByteArrayFromDictionary:[pasteboard propertyListForType:HFPrivateByteArrayPboardType]];
    return result;
}

/* Try to fix up commonly named pasteboards when a file is about to be saved */
+ (void)prepareCommonPasteboardsForChangeInFileNotification:(NSNotification *)notification {
    const BOOL *cancellationPointer = [[notification userInfo][HFChangeInFileShouldCancelKey] pointerValue];
    if (*cancellationPointer) return; //don't do anything if someone requested cancellation
    
    NSDictionary *userInfo = [notification userInfo];
    NSArray *changedRanges = userInfo[HFChangeInFileModifiedRangesKey];
    HFFileReference *fileReference = [notification object];
    NSMutableDictionary *hint = userInfo[HFChangeInFileHintKey];
    
    NSString * const names[] = {NSPasteboardNameGeneral, NSPasteboardNameFind, NSPasteboardNameDrag};
    NSUInteger i;
    for (i=0; i < sizeof names / sizeof *names; i++) {
        NSPasteboard *pboard = [NSPasteboard pasteboardWithName:names[i]];
        HFByteArray *byteArray = [self unpackByteArrayFromPasteboard:pboard];
        if (byteArray && ! [byteArray clearDependenciesOnRanges:changedRanges inFile:fileReference hint:hint]) {
            /* This pasteboard no longer works */
            [pboard declareTypes:@[] owner:nil];
        }
    }
}

- (void)changeInFileNotification:(NSNotification *)notification {
    HFASSERT(pasteboard != nil);
    HFASSERT(byteArray != nil);
    NSDictionary *userInfo = [notification userInfo];
    const BOOL *cancellationPointer = [userInfo[HFChangeInFileShouldCancelKey] pointerValue];
    if (*cancellationPointer) return; //don't do anything if someone requested cancellation
    NSMutableDictionary *hint = userInfo[HFChangeInFileHintKey];
    
    NSArray *changedRanges = [notification userInfo][HFChangeInFileModifiedRangesKey];
    HFFileReference *fileReference = [notification object];
    if (! [byteArray clearDependenciesOnRanges:changedRanges inFile:fileReference hint:hint]) {
        /* We can't do it */
        [self tearDownPasteboardReferenceIfExists];
    }
}

- (void)dealloc {
    HFASSERT_MAIN_THREAD(); // byteArrayMap is not thread safe
    HFASSERT([byteArrayMap objectForKey:byteArrayMapKey] != nil);
    [byteArrayMap removeObjectForKey:byteArrayMapKey];
    [self tearDownPasteboardReferenceIfExists];
}

- (void)writeDataInBackgroundToPasteboard:(NSPasteboard *)pboard ofLength:(unsigned long long)length forType:(NSString *)type trackingProgress:(HFProgressTracker *)tracker {
    USE(length);
    USE(pboard);
    USE(type);
    USE(tracker);
    UNIMPLEMENTED_VOID();
}

- (void)backgroundMoveDataToPasteboard:(NSString *)type {
    @autoreleasepool {
    [self writeDataInBackgroundToPasteboard:pasteboard ofLength:dataAmountToCopy forType:type trackingProgress:progressTracker];
    [self performSelectorOnMainThread:@selector(backgroundMoveDataFinished:) withObject:nil waitUntilDone:NO];
    }
}

- (void)backgroundMoveDataFinished:unused {
    USE(unused);
    HFASSERT(backgroundCopyOperationFinished == NO);
    backgroundCopyOperationFinished = YES;
    if (! didStartModalSessionForBackgroundCopyOperation) {
        /* We haven't started the modal session, so make sure it never happens */
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(beginModalSessionForBackgroundCopyOperation:) object:nil];
        CFRunLoopWakeUp(CFRunLoopGetCurrent());
    }
    else {
        /* We have started the modal session, so end it. */
        [NSApp stopModalWithCode:0];
        //stopModal: won't trigger unless we post a do-nothing event
        NSEvent *event = [NSEvent otherEventWithType:NSEventTypeApplicationDefined location:NSZeroPoint modifierFlags:0 timestamp:0 windowNumber:0 context:NULL subtype:0 data1:0 data2:0];
        [NSApp postEvent:event atStart:NO];
    }
}

- (void)beginModalSessionForBackgroundCopyOperation:(id)unused {
    USE(unused);
    HFASSERT(backgroundCopyOperationFinished == NO);
    HFASSERT(didStartModalSessionForBackgroundCopyOperation == NO);
    didStartModalSessionForBackgroundCopyOperation = YES;
    [NSApp runModalForWindow:progressTrackingWindow];
}

- (BOOL)moveDataWithProgressReportingToPasteboard:(NSPasteboard *)pboard forType:(NSString *)type {
    // The -[NSRunLoop runMode:beforeDate:] call in the middle of this function can cause it to be
    // called reentrantly, which was previously causing leaks and use-after-free crashes. For
    // some reason this happens basically always when copying lots of data into VMware Fusion.
    // I'm not even sure what the ideal behavior would be here, but am fairly certain that this
    // is the best that can be done without rewriting a portion of the background copying code.
    // TODO: Figure out what the ideal behavior should be here.
    if(progressTracker) {
        while(!backgroundCopyOperationFinished) {
            [[NSRunLoop currentRunLoop] runMode:NSModalPanelRunLoopMode beforeDate:[NSDate distantFuture]];
        }
        // Reentrant calls will complete this loop (or, in the case of the first call, the similar
        // loop below) in LIFO order. The first call is the only one that changes progressTracker,
        // so progressTracker never changes in the other calls. (If that's not true then there
        // is still a bug here).
        HFASSERT(progressTracker);
        return !progressTracker->cancelRequested;
    }
    
    HFASSERT(pboard == pasteboard);
    BOOL result = NO;
    CFRetain((CFTypeRef)self); //resolving the pasteboard may release us, which deallocates us, which deallocates our tracker...make sure we survive through this function
    /* Give the user a chance to request a smaller amount if it's really big */
    unsigned long long availableAmount = [byteArray length];
    unsigned long long amountToCopy = [self amountToCopyForDataLength:availableAmount stringLength:[self stringLengthForDataLength:availableAmount]];
    if (amountToCopy > 0) {
        HFASSERT(!progressTracker);
        HFASSERT(!progressTrackingWindow);

        progressTracker = [[HFProgressTracker alloc] init];

        NSMutableArray *topLevelObjects = [NSMutableArray array];
        if (![[NSBundle bundleForClass:[self class]] loadNibNamed:@"HFModalProgress" owner:self topLevelObjects:&topLevelObjects] || !progressTrackingWindow) {
            NSLog(@"Unable to load nib named HFModalProgress!");
        }
        backgroundCopyOperationFinished = NO;
        didStartModalSessionForBackgroundCopyOperation = NO;
        dataAmountToCopy = amountToCopy;
        unsigned long long stringAmountToCopy = [self stringLengthForDataLength:amountToCopy];
        [progressTrackingDescriptionTextField setStringValue:HFDescribeByteCountWithPrefixAndSuffix("Copying ", stringAmountToCopy, " to the clipboard")];
        [progressTracker setProgressIndicator:progressTrackingIndicator];
        [progressTracker beginTrackingProgress];
        [NSThread detachNewThreadSelector:@selector(backgroundMoveDataToPasteboard:) toTarget:self withObject:type];
        [self performSelector:@selector(beginModalSessionForBackgroundCopyOperation:) withObject:nil afterDelay:1.0 inModes:@[NSModalPanelRunLoopMode]];
        while (! backgroundCopyOperationFinished) {
            [[NSRunLoop currentRunLoop] runMode:NSModalPanelRunLoopMode beforeDate:[NSDate distantFuture]];
        }
        [progressTracker endTrackingProgress];
        [progressTrackingWindow close];
        progressTrackingWindow = nil;
        result = !progressTracker->cancelRequested;
        progressTracker = nil; // Used to detect reentrancy; zero this last.
    }
    CFRelease((CFTypeRef)self);
    return result;
}

/* Action from the cancel button of the progress dialog */
- (IBAction)requestCancel:(id)sender {
    [progressTracker requestCancel:sender];
}

- (void)pasteboardChangedOwner:(NSPasteboard *)pboard {
    HFASSERT(pasteboard == pboard);
    [self tearDownPasteboardReferenceIfExists];
}

- (HFByteArray *)byteArray {
    return byteArray;
}

- (void)pasteboard:(NSPasteboard *)pboard provideDataForType:(NSString *)type {
    if (! pasteboard) {
        /* Don't do anything, because we've torn down our pasteboard */
        return;
    }
    if ([type isEqualToString:HFPrivateByteArrayPboardType]) {
        if (! retainedSelfOnBehalfOfPboard) {
            retainedSelfOnBehalfOfPboard = YES;
            CFRetain((CFTypeRef)self);
        }
        NSDictionary *dict = @{@"HFByteArray": byteArrayMapKey,
                              @"HFUUID": [[self class] uuid]};
        [pboard setPropertyList:dict forType:type];
    }
    else {
        if (! [self moveDataWithProgressReportingToPasteboard:pboard forType:type]) {
            [pboard setData:[NSData data] forType:type];
        }
    }
}

- (void)setBytesPerLine:(NSUInteger)val { bytesPerLine = val; }
- (NSUInteger)bytesPerLine { return bytesPerLine; }

+ (NSString *)createUUI {
    CFUUIDRef uuidRef = CFUUIDCreate(NULL);
    HFASSERT(uuidRef != NULL);
    NSString *ret = (__bridge_transfer NSString *)CFUUIDCreateString(NULL, uuidRef);
    CFRelease(uuidRef);
    return ret;
}

+ (NSString *)uuid {
    static NSString *uuid;
    if (! uuid) {
        uuid = [self createUUI];
    }
    return uuid;
}

- (unsigned long long)stringLengthForDataLength:(unsigned long long)dataLength { USE(dataLength); UNIMPLEMENTED(); }

- (unsigned long long)amountToCopyForDataLength:(unsigned long long)numBytes stringLength:(unsigned long long)stringLength {
    unsigned long long dataLengthResult, stringLengthResult;
    const unsigned long long copyOption1 = MAXIMUM_PASTEBOARD_SIZE_TO_EXPORT;
    const unsigned long long copyOption2 = MINIMUM_PASTEBOARD_SIZE_TO_WARN_ABOUT;
    NSString *option1String = HFDescribeByteCount(copyOption1);
    NSString *option2String = HFDescribeByteCount(copyOption2);
    NSString* dataSizeDescription = HFDescribeByteCount(stringLength);
    if (stringLength >= MAXIMUM_PASTEBOARD_SIZE_TO_EXPORT) {
        NSString *option1 = [@"Copy " stringByAppendingString:option1String];
        NSString *option2 = [@"Copy " stringByAppendingString:option2String];
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = NSLocalizedString(@"Large Clipboard", nil);
        alert.informativeText = [NSString stringWithFormat:@"The copied data would occupy %@ if written to the clipboard.  This is larger than the system clipboard supports.  Do you want to copy only part of the data?", dataSizeDescription];
        [alert addButtonWithTitle:NSLocalizedString(@"Cancel", nil)];
        [alert addButtonWithTitle:option1];
        [alert addButtonWithTitle:option2];
        NSModalResponse alertReturn = [alert runModal];
        switch (alertReturn) {
            case NSAlertFirstButtonReturn:
            default:
                stringLengthResult = 0;
                break;
            case NSAlertSecondButtonReturn:
                stringLengthResult = copyOption1;
                break;
            case NSAlertThirdButtonReturn:
                stringLengthResult = copyOption2;
                break;
        }
        
    }
    else if (stringLength >= MINIMUM_PASTEBOARD_SIZE_TO_WARN_ABOUT) {
        NSString *option1 = [@"Copy " stringByAppendingString:HFDescribeByteCount(stringLength)];
        NSString *option2 = [@"Copy " stringByAppendingString:HFDescribeByteCount(copyOption2)];
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = NSLocalizedString(@"Large Clipboard", nil);
        alert.informativeText = [NSString stringWithFormat:@"The copied data would occupy %@ if written to the clipboard.  Performing this copy may take a long time.  Do you want to copy only part of the data?", dataSizeDescription];
        [alert addButtonWithTitle:NSLocalizedString(@"Cancel", nil)];
        [alert addButtonWithTitle:option1];
        [alert addButtonWithTitle:option2];
        NSModalResponse alertReturn = [alert runModal];
        switch (alertReturn) {
            case NSAlertFirstButtonReturn:
            default:
                stringLengthResult = 0;
                break;
            case NSAlertSecondButtonReturn:
                stringLengthResult = stringLength;
                break;
            case NSAlertThirdButtonReturn:
                stringLengthResult = copyOption2;
                break;
        }
    }
    else {
        /* Small enough to copy it all */
        stringLengthResult = stringLength;
    }
    
    /* Convert from string length to data length */
    if (stringLengthResult == stringLength) {
        dataLengthResult = numBytes;
    }
    else {
        unsigned long long divisor = stringLength / numBytes;
        dataLengthResult = stringLengthResult / divisor;
    }
    
    return dataLengthResult;
}

@end
