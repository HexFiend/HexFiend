//
//  HFFindReplaceOperationView.m
//  HexFiend_2
//
//  Copyright (c) 2011 ridiculous_fish. All rights reserved.
//

#import "HFFindReplaceOperationView.h"
#import "BaseDataDocument.h"
#import <HexFiend/HFEncodingManager.h>

@implementation HFFindReplaceOperationView

- (instancetype)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    fieldTypeIsASCII = 	[[NSUserDefaults standardUserDefaults] boolForKey:@"FindPrefersASCII"];
    return self;
}

- (void)setFindField:(HFTextField *)field {
    findField = field;
    [findField setUsesHexArea: ! fieldTypeIsASCII];
    [findField setUsesTextArea: fieldTypeIsASCII];
}

- (void)setReplaceField:(HFTextField *)field {
    replaceField = field;
    [replaceField setUsesHexArea: ! fieldTypeIsASCII];
    [replaceField setUsesTextArea: fieldTypeIsASCII];
}

- (void)setFieldTypeControl:(NSSegmentedControl *)val {
    fieldTypeControl = val;
}

- (void)updateFieldEditability {
    BOOL shouldBeEditable = ! [self operationIsRunning];
    [findField setEditable:shouldBeEditable];
    [replaceField setEditable:shouldBeEditable];
}

- (BOOL)fieldTypeIsASCII {
    return fieldTypeIsASCII;
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
    
    [fieldTypeControl setSelectedSegment:(fieldTypeIsASCII ? 1 : 0)];
}

- (BaseDataDocument *)document {
    return document;
}

- (void)setDocument:(id)val {
    document = val;
}

- (IBAction)modifyFieldTypeFromControl:(NSSegmentedControl *)sender {
    [self setFieldTypeIsASCII: ([sender selectedSegment] ? YES : NO)];
}

- (void)updateTextFieldStringEncodingFromDocumentNotification:(id)unused {
    USE(unused);
    HFStringEncoding *encoding;
    if (document) {
        encoding = [document stringEncoding];
    } else {
        encoding = [HFEncodingManager shared].ascii;
    }
    [findField setStringEncoding:encoding];
    [replaceField setStringEncoding:encoding];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([keyPath isEqualToString:@"operationIsRunning"]) {
        [self updateFieldEditability];
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (void)awakeFromNib {
    [super awakeFromNib];

    [fieldTypeControl setSelectedSegment:(fieldTypeIsASCII ? 1 : 0)];

    [self addObserver:self forKeyPath:@"operationIsRunning" options:NSKeyValueObservingOptionInitial context:NULL];

    if (! installedObservations) {
        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
        
        /* Observe the document for changes in its string encoding */
        [nc addObserver:self selector:@selector(updateTextFieldStringEncodingFromDocumentNotification:) name:BaseDataDocumentDidChangeStringEncodingNotification object:document];
        
        installedObservations = YES;
    }
    [self updateTextFieldStringEncodingFromDocumentNotification:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self removeObserver:self forKeyPath:@"operationIsRunning"];
}

@end
