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

- (IBAction)compareRange:(id)sender {
    USE(sender);
    
    long long start = [startOfRange.stringValue longLongValue];
    if (start <= 0) start = 0;
    
    long long len = [lengthOfRange.stringValue longLongValue];
    if (len <= 0) len = 1024;
    
    HFRange range = HFRangeMake(start, len);
    
    [NSApp stopModal];
    [self close];

    [DiffDocument compareFrontTwoDocumentsUsingRange:range];
}

- (void)runModal
{
    [self showWindow:self];
    [NSApp runModalForWindow:self.window];
}

@end
