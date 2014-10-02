//
//  DiffRangeWindowController.m
//  HexFiend_2
//
//  Created by Steven Rogers on 03/14/13.
//  Copyright (c) 2013 ridiculous_fish. All rights reserved.
//

#import "DiffRangeWindowController.h"

#import "DiffDocument.h"

@implementation DiffRangeWindowController

- (instancetype)initWithWindow:(NSWindow *)window {
    self = [super initWithWindow:window];
    if (!self) return self;
    return self;
}

- (IBAction)compareRange:(id)sender {
    USE(sender);
    
    long long start = [startOfRange.stringValue longLongValue];
    if (start <= 0) start = 0;
    
    long long len = [lengthOfRange.stringValue longLongValue];
    if (len <= 0) len = 1024;
    
    HFRange range = HFRangeMake(start, len);
    
    [DiffDocument compareFrontTwoDocumentsUsingRange:range];
    
    [self close];
}

@end
