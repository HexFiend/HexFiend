//
//  HFBinaryTemplateController.m
//  HexFiend_2
//
//  Created by Kevin Wojniak on 1/7/18.
//  Copyright © 2018 ridiculous_fish. All rights reserved.
//

#import "HFBinaryTemplateController.h"
#import "HFTemplateNode.h"

@interface HFTemplateFile : NSObject

@property (copy) NSString *path;
@property (copy) NSString *name;

@end

@implementation HFTemplateFile

@end

@interface HFBinaryTemplateController () <NSTableViewDataSource, NSTableViewDelegate>

@property (weak) IBOutlet NSTableView *tableView;
@property (weak) IBOutlet NSTextField *errorTextField;
@property (weak) IBOutlet NSPopUpButton *templatesPopUp;

@property HFTemplateNode *node;
@property NSArray<HFTemplateFile*> *templates;

@end

@implementation HFBinaryTemplateController

- (void)loadTemplates:(id __unused)sender {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *dir = [[NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES).firstObject stringByAppendingPathComponent:[NSBundle mainBundle].bundleIdentifier] stringByAppendingPathComponent:@"Templates"];
    NSMutableArray<HFTemplateFile*> *templates = [NSMutableArray array];
    for (NSString *filename in [fm contentsOfDirectoryAtPath:dir error:nil]) {
        if ([filename.pathExtension isEqualToString:@"tcl"]) {
            HFTemplateFile *file = [[HFTemplateFile alloc] init];
            file.path = [dir stringByAppendingPathComponent:filename];
            file.name = [filename stringByDeletingPathExtension];
            [templates addObject:file];
        }
    }
    [templates sortUsingDescriptors:@[[[NSSortDescriptor alloc] initWithKey:@"name" ascending:YES]]];
    [self.templatesPopUp removeAllItems];
    NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"None", nil) action:@selector(noTemplate:) keyEquivalent:@""];
    item.target = self;
    [self.templatesPopUp.menu addItem:item];
    [self.templatesPopUp.menu addItem:[NSMenuItem separatorItem]];
    if (templates.count > 0) {
        for (HFTemplateFile *file in templates) {
            [self.templatesPopUp addItemWithTitle:file.name];
        }
        [self.templatesPopUp.menu addItem:[NSMenuItem separatorItem]];
    }
    item = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Refresh", nil) action:@selector(loadTemplates:) keyEquivalent:@""];
    item.target = self;
    [self.templatesPopUp.menu addItem:item];
    self.templates = templates;
}

- (void)awakeFromNib {
    [self loadTemplates:self];
}

- (void)noTemplate:(id __unused)sender {
    
}

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

- (void)setRootNode:(HFTemplateNode *)node error:(NSString *)error {
    if (error != nil) {
        self.node = nil;
        self.errorTextField.stringValue = error;
        self.errorTextField.hidden = NO;
    } else {
        self.node = node;
        self.errorTextField.hidden = YES;
    }
    [self.tableView reloadData];
}

@end
