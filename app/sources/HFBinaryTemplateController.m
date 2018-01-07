//
//  HFBinaryTemplateController.m
//  HexFiend_2
//
//  Created by Kevin Wojniak on 1/7/18.
//  Copyright © 2018 ridiculous_fish. All rights reserved.
//

#import "HFBinaryTemplateController.h"
#import "HFTemplateNode.h"

@interface HFBinaryTemplateController () <NSTableViewDataSource, NSTableViewDelegate>

@property (weak) IBOutlet NSTableView *tableView;
@property HFTemplateNode *node;

@end

@implementation HFBinaryTemplateController

- (NSInteger)numberOfRowsInTableView:(NSTableView * __unused)tableView {
    return self.node.children.count;
}

- (id)tableView:(NSTableView * __unused)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    HFTemplateNode *node = [self.node.children objectAtIndex:row];
    NSString *ident = tableColumn.identifier;
    if ([ident isEqualToString:@"name"]) {
        return node.label;
    }
    if ([ident isEqualToString:@"value"]) {
        return node.value;
    }
    return nil;
}

- (void)setRootNode:(HFTemplateNode *)node {
    self.node = node;
    [self.tableView reloadData];
}

@end
