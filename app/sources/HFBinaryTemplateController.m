//
//  HFBinaryTemplateController.m
//  HexFiend_2
//
//  Created by Kevin Wojniak on 1/7/18.
//  Copyright © 2018 ridiculous_fish. All rights reserved.
//

#import "HFBinaryTemplateController.h"

@interface HFBinaryTemplateController () <NSTableViewDataSource, NSTableViewDelegate>

@property (weak) IBOutlet NSTableView *tableView;

@end

@implementation HFBinaryTemplateController

- (NSInteger)numberOfRowsInTableView:(NSTableView * __unused)tableView {
    return 5;
}

- (id)tableView:(NSTableView * __unused)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    (void)row;
    NSString *ident = tableColumn.identifier;
    if ([ident isEqualToString:@"name"]) {
        return @"Name";
    }
    if ([ident isEqualToString:@"value"]) {
        return @"Value";
    }
    return nil;
}

@end
