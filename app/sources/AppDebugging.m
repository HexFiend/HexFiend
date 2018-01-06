//
//  AppDebugging.m
//  HexFiend_2
//
//  Copyright 2011 ridiculous_fish. All rights reserved.
//

#import "AppDebugging.h"
#import "AppUtilities.h"

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
    [menu addItem:[NSMenuItem separatorItem]];
    [menu addItemWithTitle:@"Show ByteArray" action:@selector(_showByteArray:) keyEquivalent:@"k"];
    [[[menu itemArray] lastObject] setKeyEquivalentModifierMask:NSCommandKeyMask];
    [menu addItemWithTitle:@"Randomly Tweak ByteArray" action:@selector(_tweakByteArray:) keyEquivalent:@""];
    [menu addItemWithTitle:@"Random ByteArray" action:@selector(_randomByteArray:) keyEquivalent:@""];
    
}

static NSString *promptForValue(NSString *promptText) {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = promptText;
    alert.informativeText = @"";
    [alert addButtonWithTitle:NSLocalizedString(@"OK", "")];
    [alert addButtonWithTitle:NSLocalizedString(@"Cancel", "")];
    NSTextField *textField = [[NSTextField alloc] init];
    [textField sizeToFit];
    NSRect frame = textField.frame;
    frame.size.width = 200;
    textField.frame = frame;
    alert.accessoryView = textField;
    if ([alert runModal] != NSAlertFirstButtonReturn) {
        return nil;
    }
    return textField.stringValue;
}

- (void)_showByteArray:sender {
    USE(sender);
    NSLog(@"%@", [controller byteArray]);
}

- (void)_randomByteArray:sender {
    USE(sender);
    unsigned long long length = unsignedLongLongValue(promptForValue(NSLocalizedString(@"How long?", "")));
    Class clsHFRandomDataByteSlice = NSClassFromString(@"HFRandomDataByteSlice");
    HFByteSlice *slice = [[clsHFRandomDataByteSlice alloc] initWithRandomDataLength:length];
    HFByteArray *array = [[HFBTreeByteArray alloc] init];
    [array insertByteSlice:slice inRange:HFRangeMake(0, 0)];
    [controller insertByteArray:array replacingPreviousBytes:0 allowUndoCoalescing:NO];
}

- (void)_tweakByteArray:sender {
    USE(sender);
    
    unsigned tweakCount = [promptForValue(NSLocalizedString(@"How many tweaks?", "")) intValue];
    
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
