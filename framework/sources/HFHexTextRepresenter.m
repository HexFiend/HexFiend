//
//  HFHexTextRepresenter.m
//  HexFiend_2
//
//  Created by Peter Ammon on 11/3/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <HexFiend/HFHexTextRepresenter.h>
#import <HexFiend/HFRepresenterHexTextView.h>

@implementation HFHexTextRepresenter

- (Class)_textViewClass {
    return [HFRepresenterHexTextView class];
}

- (void)initializeView {
    [super initializeView];
    [[self view] setBytesBetweenVerticalGuides:4];
    unpartneredLastNybble = UCHAR_MAX;
    omittedNybbleLocation = ULLONG_MAX;
}

+ (NSPoint)defaultLayoutPosition {
    return NSMakePoint(0, 0);
}

- (void)_clearOmittedNybble {
    unpartneredLastNybble = UCHAR_MAX;
    omittedNybbleLocation = ULLONG_MAX;
}

- (BOOL)_insertionShouldDeleteLastNybble {
    /* Either both the omittedNybbleLocation and unpartneredLastNybble are invalid (set to their respective maxima), or neither are */
    HFASSERT((omittedNybbleLocation == ULLONG_MAX) == (unpartneredLastNybble == UCHAR_MAX));
    /* We should delete the last nybble if our omittedNybbleLocation is the point where we would insert */
    BOOL result = NO;
    if (omittedNybbleLocation != ULLONG_MAX) {
        HFController *controller = [self controller];
        NSArray *selectedRanges = [controller selectedContentsRanges];
        if ([selectedRanges count] == 1) {
            HFRange selectedRange = [[selectedRanges objectAtIndex:0] HFRange];
            result = (selectedRange.length == 0 && selectedRange.location == omittedNybbleLocation);
        }
    }
    return result;
}

- (BOOL)_canInsertText:(NSString *)text {
    REQUIRE_NOT_NULL(text);
    NSCharacterSet *characterSet = [NSCharacterSet characterSetWithCharactersInString:@"0123456789ABCDEFabcdef"];
    return [text rangeOfCharacterFromSet:characterSet].location != NSNotFound;
}

- (void)insertText:(NSString *)text {
    REQUIRE_NOT_NULL(text);
    HFASSERT([text length] > 0);
    if (! [self _canInsertText:text]) {
        /* The user typed invalid data, and we can ignore it */
        return;
    }
    
    BOOL shouldReplacePriorByte = [self _insertionShouldDeleteLastNybble];
    if (shouldReplacePriorByte) {
        HFASSERT(unpartneredLastNybble < 16);
        /* Prepend unpartneredLastNybble as a nybble */
        text = [NSString stringWithFormat:@"%1X%@", unpartneredLastNybble, text];
    }
    BOOL isMissingLastNybble;
    NSData *data = HFDataFromHexString(text, &isMissingLastNybble);
    HFASSERT([data length] > 0);
    HFASSERT(shouldReplacePriorByte != isMissingLastNybble);
    HFController *controller = [self controller];
    [controller insertData:data replacingPreviousBytes: shouldReplacePriorByte ? 1 : 0];
    if (isMissingLastNybble) {
        HFASSERT([data length] > 0);
        HFASSERT(unpartneredLastNybble == UCHAR_MAX);
        [data getBytes:&unpartneredLastNybble range:NSMakeRange([data length] - 1, 1)];
        NSArray *selectedRanges = [controller selectedContentsRanges];
        HFASSERT([selectedRanges count] == 1);
        HFRange selectedRange = [[selectedRanges objectAtIndex:0] HFRange];
        HFASSERT(selectedRange.length == 0);
        omittedNybbleLocation = selectedRange.location;
    }
    else {
        [self _clearOmittedNybble];
    }
}

- (void)controllerDidChange:(HFControllerPropertyBits)bits {
    [super controllerDidChange:bits];
    if (bits & (HFControllerContentValue | HFControllerContentLength | HFControllerSelectedRanges)) {
        NSLog(@"Clearing");
        [self _clearOmittedNybble];
    }
}

@end
