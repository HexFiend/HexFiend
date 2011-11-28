//
//  HFFieldTypeController.m
//  HexFiend_2
//
//  Created by Peter Ammon on 4/4/08.
//  Copyright 2008 ridiculous_fish. All rights reserved.
//

#import "HFFieldTypeController.h"
#import "BaseDataDocument.h"
#import <HexFiend/HFTextField.h>

@implementation HFFieldTypeController

- (BOOL)operationIsRunning {
    return operationIsRunning;
}

- (void)setOperationIsRunning:(BOOL)val {
    operationIsRunning = val;
}

- init {
    self = [super init];
    fieldTypeIsASCII = 	[[NSUserDefaults standardUserDefaults] boolForKey:@"FindPrefersASCII"];
    return self;
}

- (BOOL)fieldTypeIsASCII {
    return fieldTypeIsASCII;
}

- (void)setFindField:(HFTextField *)field {
    [field retain];
    [findField release];
    findField = field;
    [findField setUsesHexArea: ! fieldTypeIsASCII];
    [findField setUsesTextArea: fieldTypeIsASCII];
}

- (void)setReplaceField:(HFTextField *)field {
    [field retain];
    [replaceField release];
    replaceField = field;
    [replaceField setUsesHexArea: ! fieldTypeIsASCII];
    [replaceField setUsesTextArea: fieldTypeIsASCII];
}

- (void)setFieldTypeIsASCII:(BOOL)val {
    fieldTypeIsASCII = val;
    [[NSUserDefaults standardUserDefaults] setBool:val forKey:@"FindPrefersASCII"];
    id firstResponder = [[findField window] firstResponder];
    if (! [firstResponder isKindOfClass:[NSView class]]) firstResponder = nil;
    BOOL restoreFRToFind = ([firstResponder ancestorSharedWithView:findField] == findField);
    BOOL restoreFRToReplace = ([firstResponder ancestorSharedWithView:replaceField] == replaceField);
    [findField setUsesHexArea: ! fieldTypeIsASCII];
    [findField setUsesTextArea: fieldTypeIsASCII];
    [replaceField setUsesHexArea: ! fieldTypeIsASCII];
    [replaceField setUsesTextArea: fieldTypeIsASCII];
    if (restoreFRToFind) [[findField window] makeFirstResponder:findField];
    if (restoreFRToReplace) [[replaceField window] makeFirstResponder:replaceField];
}

- (void)updateTextFieldStringEncodingFromDocument {
    NSStringEncoding encoding;
    if (document) {
        encoding = [document stringEncoding];
    } else {
        encoding = [NSString defaultCStringEncoding];
    }
    [findField setStringEncoding:encoding];
    [replaceField setStringEncoding:encoding];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (object == document && [keyPath isEqualToString:@"stringEncoding"]) {
        [self updateTextFieldStringEncodingFromDocument];
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (void)awakeFromNib {
    if (document && ! observingDocument) {
        /* Observe the document for changes in its string encoding */
        [document addObserver:self forKeyPath:@"stringEncoding" options:0 context:NULL];
        observingDocument = YES;
    }
    [self updateTextFieldStringEncodingFromDocument];
}

- (void)setOperationView:(HFDocumentOperationView *)view {
    operationView = view;
    [self bind:@"operationIsRunning" toObject:view withKeyPath:@"operationIsRunning" options:nil];
}

- (void)dealloc {
    [self unbind:@"operationIsRunning"];
    /* Oooh this is sketchy to do this here */
    if (observingDocument) {
        [document removeObserver:self forKeyPath:@"stringEncoding"];
        observingDocument = NO;
    }
    [super dealloc];
}

@end
