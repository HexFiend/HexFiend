//
//  HFTextField.m
//  HexFiend_2
//
//  Copyright 2008 ridiculous_fish. All rights reserved.
//

#import <HexFiend/HFTextField.h>
#import <HexFiend/HFBTreeByteArray.h>
#import <HexFiend/HFController.h>
#import <HexFiend/HFLayoutRepresenter.h>
#import <HexFiend/HFHexTextRepresenter.h>
#import <HexFiend/HFStringEncodingTextRepresenter.h>
#import <HexFiend/HFAssert.h>

@implementation HFTextField

- (void)positionLayoutView {
    NSRect viewFrame = [self bounds];
    viewFrame.size.height -= 3;
    viewFrame.origin.y += 1;
    viewFrame.origin.x += 1;
    viewFrame.size.width -= 2;
    [[layoutRepresenter view] setFrame:viewFrame];
}

- (instancetype)initWithFrame:(NSRect)frame {
    if ((self = [super initWithFrame:frame])) {
        dataController = [[HFController alloc] init];
        
        hexRepresenter = [[HFHexTextRepresenter alloc] init];
        [hexRepresenter setBehavesAsTextField:YES];
        [(NSView *)[hexRepresenter view] setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
        
        textRepresenter = [[HFStringEncodingTextRepresenter alloc] init];
        [textRepresenter setBehavesAsTextField:YES];
        [(NSView *)[textRepresenter view] setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
        
        
        [dataController addRepresenter:hexRepresenter];
        
        layoutRepresenter = [[HFLayoutRepresenter alloc] init];
        [layoutRepresenter addRepresenter:hexRepresenter];
        [dataController addRepresenter:layoutRepresenter];
        NSView *layoutView = [layoutRepresenter view];
        [layoutView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
        [self positionLayoutView];
        [self addSubview:layoutView];
    }
    return self;
}

- (void)resizeSubviewsWithOldSize:(NSSize)oldSize {
    USE(oldSize);
    [self positionLayoutView];
}

- (void)drawRect:(NSRect)rect {
    USE(rect);
    NSRect bounds = [self bounds];
    NSRect horizontalLine = NSMakeRect(NSMinX(bounds), NSMaxY(bounds) - 1, NSWidth(bounds), 1);
    NSRect verticalLine = NSMakeRect(NSMinX(bounds), 1, 1, NSHeight(bounds) - 2);
    NSRect lines[5];
    NSColor *colors[5] = {
        [NSColor colorWithCalibratedWhite:(CGFloat)(114./255.) alpha:1],
        [NSColor colorWithCalibratedWhite:(CGFloat)(203./255.) alpha:1],
        [NSColor colorWithCalibratedWhite:(CGFloat)(218./255.) alpha:1],
        [NSColor colorWithCalibratedWhite:(CGFloat)(180./255.) alpha:1],
        [NSColor colorWithCalibratedWhite:(CGFloat)(180./255.) alpha:1]
    };
    lines[0] = horizontalLine;
    horizontalLine.origin.y -= 1;
    lines[1] = horizontalLine;
    horizontalLine.origin.y = NSMinY(bounds);
    lines[2] = horizontalLine;
    lines[3] = verticalLine;
    verticalLine.origin.x = NSMaxX(bounds) - verticalLine.size.width;
    lines[4] = verticalLine;
    
    NSRectFillListWithColors(lines, colors, 5);
}

- (BOOL)becomeFirstResponder {
    if ([self usesHexArea]) return [[self window] makeFirstResponder:[hexRepresenter view]];
    else if ([self usesTextArea]) return [[self window] makeFirstResponder:[textRepresenter view]]; 
    else return NO;
}

- (void)insertNewline:sender {
    USE(sender);
    [self sendAction:[self action] to:[self target]];
}

- (id)target {
    return target;
}

- (SEL)action {
    return action;
}

- (void)setTarget:(id)val {
    target = val;
}

- (void)setAction:(SEL)val {
    action = val;
}

- (id)objectValue {
    return [dataController byteArray];
}

- (void)setObjectValue:(id)value {
    EXPECT_CLASS(value, HFByteArray);
    [dataController setByteArray:value];
}

- (BOOL)usesRepresenter:(HFRepresenter *)rep {
    REQUIRE_NOT_NULL(rep);
    HFASSERT(rep == hexRepresenter || rep == textRepresenter);
    BOOL result = NO;
    NSArray *reps = dataController.representers;
    if (reps) {
        result = ([reps indexOfObjectIdenticalTo:rep] != NSNotFound);
    }
    return result;
}

- (BOOL)usesHexArea {
    return [self usesRepresenter:hexRepresenter];
}

- (void)setUsesHexArea:(BOOL)val {
    if ([self usesHexArea] == !!val) return;
    if (val) {
        [dataController addRepresenter:hexRepresenter];
        [layoutRepresenter addRepresenter:hexRepresenter];
    }
    else {
        [layoutRepresenter removeRepresenter:hexRepresenter];
        [dataController removeRepresenter:hexRepresenter];
    }
}


- (BOOL)usesTextArea {
    return [self usesRepresenter:textRepresenter];
}

- (void)setUsesTextArea:(BOOL)val {
    if ([self usesTextArea] == !!val) return;
    if (val) {
        [dataController addRepresenter:textRepresenter];
        [layoutRepresenter addRepresenter:textRepresenter];
    }
    else {
        [layoutRepresenter removeRepresenter:textRepresenter];
        [dataController removeRepresenter:textRepresenter];
    }
}

- (void)setStringEncoding:(HFStringEncoding *)encoding {
    [textRepresenter setEncoding:encoding];
}

- (HFStringEncoding *)stringEncoding {
    return [textRepresenter encoding];
}

- (void)setEditable:(BOOL)flag {
    [dataController setEditable:flag];
}

- (BOOL)isEditable {
    return [dataController editable];
}

- (void)selectAll:(id)sender {
    HFTextRepresenter *rep = nil;
    if ([self usesHexArea]) {
        rep = hexRepresenter;
    } else if ([self usesTextArea]) {
        rep = textRepresenter;
    } else {
        HFASSERT(0);
        NSBeep();
    }
    [rep selectAll:sender];
}

@end
