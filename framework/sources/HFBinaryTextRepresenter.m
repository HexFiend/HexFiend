//
//  HFBinaryTextRepresenter.m
//  HexFiend_2
//
//  Copyright 2020 ridiculous_fish. All rights reserved.
//

#import <HexFiend/HFBinaryTextRepresenter.h>
#import "HFRepresenterBinaryTextView.h"

@implementation HFBinaryTextRepresenter

- (Class)_textViewClass {
    return [HFRepresenterBinaryTextView class];
}

- (void)initializeView {
    [super initializeView];
    [(HFRepresenterTextView *)[self view] setBytesBetweenVerticalGuides:4];
}

+ (CGPoint)defaultLayoutPosition {
    return CGPointMake(0, 0);
}

- (BOOL)_canInsertText:(NSString *)text {
    REQUIRE_NOT_NULL(text);
    NSCharacterSet *characterSet = [NSCharacterSet characterSetWithCharactersInString:@"01"];
    return [text rangeOfCharacterFromSet:characterSet].location != NSNotFound;
}

- (void)insertText:(NSString *)text {
    REQUIRE_NOT_NULL(text);
    if (! [self _canInsertText:text]) {
        /* The user typed invalid data, and we can ignore it */
        return;
    }
    
    // TODO
}

- (NSData *)dataFromPasteboardString:(NSString *)string {
    REQUIRE_NOT_NULL(string);
    // TODO
    return nil;
}

#if !TARGET_OS_IPHONE
- (void)copySelectedBytesToPasteboard:(NSPasteboard *)pb {
    // TODO
}
#endif

@end
