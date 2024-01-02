//
//  AppDebugging.m
//  HexFiend_2
//
//  Copyright 2011 ridiculous_fish. All rights reserved.
//

#import "AppDebugging.h"
#import "AppUtilities.h"
#import "HFPrompt.h"

static unsigned long long unsignedLongLongValue(NSString *s) {
    unsigned long long result = 0;
    parseNumericStringWithSuffix(s, &result, NULL);
    return result;
}

@interface HFRandomDataByteSlice : HFByteSlice
- (HFRandomDataByteSlice *)initWithRandomDataLength:(unsigned long long)length;
@end


@implementation BaseDataDocument (AppDebugging)

- (void)installDebuggingMenuItems:(NSMenu *)menu {
    [menu addItemWithTitle:@"Scroller" action:@selector(toggleScrollerVisibleControllerView) keyEquivalent:@""];
    [menu addItemWithTitle:@"Text Divider" action:@selector(toggleTextDividerVisibleControllerView) keyEquivalent:@""];
    [menu addItemWithTitle:@"Scroll View" action:@selector(toggleScrollViewVisibleControllerView) keyEquivalent:@""];
    [menu addItem:[NSMenuItem separatorItem]];
    [menu addItemWithTitle:@"Randomly Tweak ByteArray" action:@selector(_tweakByteArray:) keyEquivalent:@""];
    [menu addItemWithTitle:@"Random ByteArray" action:@selector(_randomByteArray:) keyEquivalent:@""];
    
}

- (void)_randomByteArray:sender {
    USE(sender);
    unsigned long long length = unsignedLongLongValue(HFPromptForValue(NSLocalizedString(@"How long?", "")));
    Class clsHFRandomDataByteSlice = NSClassFromString(@"HFRandomDataByteSlice");
    HFByteSlice *slice = [[clsHFRandomDataByteSlice alloc] initWithRandomDataLength:length];
    HFByteArray *array = [[HFBTreeByteArray alloc] init];
    [array insertByteSlice:slice inRange:HFRangeMake(0, 0)];
    [controller insertByteArray:array replacingPreviousBytes:0 allowUndoCoalescing:NO];
}

- (void)_tweakByteArray:sender {
    USE(sender);
    
    unsigned tweakCount = [HFPromptForValue(NSLocalizedString(@"How many tweaks?", "")) intValue];
    
    HFByteArray *byteArray = [[controller byteArray] mutableCopy];
    unsigned i;
    Class clsHFRandomDataByteSlice = NSClassFromString(@"HFRandomDataByteSlice");
    for (i=1; i <= tweakCount; i++) {
	@autoreleasepool {
	NSUInteger op;
	const unsigned long long length = [byteArray length];
	unsigned long long offset;
	unsigned long long number;
	switch ((op = (random()%2))) {
	    case 0: { //insert
		offset = random() % (1 + length);
		HFByteSlice* slice = [[clsHFRandomDataByteSlice alloc] initWithRandomDataLength: 1 + random() % 1000];
		[byteArray insertByteSlice:slice inRange:HFRangeMake(offset, 0)];
		break;
	    }
	    case 1: { //delete
		if (length > 0) {
                    number = (NSUInteger)sqrt(random() % length);
                    offset = 1 + random() % (length - number);
		    [byteArray deleteBytesInRange:HFRangeMake(offset, number)];
		}
		break;
	    }
	}
    } // @autoreleasepool
    }
    [controller replaceByteArray:byteArray];
}

@end
