//
//  HFBinaryTemplateController.m
//  HexFiend_2
//
//  Created by Kevin Wojniak on 1/7/18.
//  Copyright © 2018 ridiculous_fish. All rights reserved.
//

#import "HFBinaryTemplateController.h"
#import "HFTemplateNode.h"
#import "HFTclTemplateController.h"
#import "HFColorRange.h"

@interface NSObject (HFTemplateOutlineViewDelegate)

- (NSMenu *)outlineView:(NSOutlineView *)sender menuForEvent:(NSEvent *)event;

@end

@interface HFTemplateOutlineView : NSOutlineView

@end

@implementation HFTemplateOutlineView

- (NSMenu *)menuForEvent:(NSEvent *)event {
    if ([self.delegate respondsToSelector:@selector(outlineView:menuForEvent:)]) {
        return [(id)self.delegate outlineView:self menuForEvent:event];
    }
    return nil;
}

@end

@interface HFTemplateFile : NSObject

@property (copy) NSString *path;
@property (copy) NSString *name;

@end

@implementation HFTemplateFile

@end

@interface HFBinaryTemplateController () <NSOutlineViewDataSource, NSOutlineViewDelegate>

@property (weak) IBOutlet NSOutlineView *outlineView;
@property (weak) IBOutlet NSTextField *errorTextField;
@property (weak) IBOutlet NSPopUpButton *templatesPopUp;

@property HFController *controller;
@property HFTemplateNode *node;
@property NSArray<HFTemplateFile*> *templates;
@property (strong) HFTclTemplateController *templateController;
@property HFTemplateFile *selectedFile;
@property NSMenuItem *lastItem;
@property HFColorRange *colorRange;

@end

@implementation HFBinaryTemplateController

- (instancetype)init {
    if ((self = [super initWithNibName:@"BinaryTemplateController" bundle:nil]) != nil) {
        _templateController = [[HFTclTemplateController alloc] init];
    }
    return self;
}

- (void)awakeFromNib {
    [self loadTemplates:self];

    [[NSUserDefaults standardUserDefaults] addObserver:self
                                            forKeyPath:@"BinaryTemplateSelectionColor"
                                               options:0
                                               context:NULL];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> * __unused)change context:(void * __unused)context {
    if (object == [NSUserDefaults standardUserDefaults]) {
        if ([keyPath isEqualToString:@"BinaryTemplateSelectionColor"]) {
            [self updateSelectionColor];
        }
    }
}

- (NSString *)templatesFolder {
    return [[NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES).firstObject stringByAppendingPathComponent:[NSBundle mainBundle].bundleIdentifier] stringByAppendingPathComponent:@"Templates"];
}

- (void)openTemplatesFolder:(id __unused)sender {
    NSString *dir = self.templatesFolder;
    NSError *error = nil;
    if (![[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:&error]) {
        NSAlert *alert = [NSAlert alertWithError:error];
        [alert runModal];
    } else if (![[NSWorkspace sharedWorkspace] selectFile:nil inFileViewerRootedAtPath:dir]) {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = NSLocalizedString(@"Failed to open folder.", nil);
        [alert runModal];
    }
    [self.templatesPopUp selectItem:self.lastItem];
}

- (void)loadTemplates:(id __unused)sender {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *dir = self.templatesFolder;
    NSMutableArray<HFTemplateFile*> *templates = [NSMutableArray array];
    for (NSString *filename in [fm enumeratorAtPath:dir]) {
        if ([filename.pathExtension isEqualToString:@"tcl"]) {
            HFTemplateFile *file = [[HFTemplateFile alloc] init];
            file.path = [dir stringByAppendingPathComponent:filename];
            file.name = [[filename lastPathComponent] stringByDeletingPathExtension];
            [templates addObject:file];
        }
    }
    [templates sortUsingDescriptors:@[[[NSSortDescriptor alloc] initWithKey:@"name" ascending:YES]]];
    [self.templatesPopUp removeAllItems];
    NSMenuItem *noneItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"None", nil) action:@selector(noTemplate:) keyEquivalent:@""];
    noneItem.target = self;
    [self.templatesPopUp.menu addItem:noneItem];
    [self.templatesPopUp.menu addItem:[NSMenuItem separatorItem]];
    NSMenuItem *itemToSelect = noneItem;
    if (templates.count > 0) {
        for (HFTemplateFile *file in templates) {
            NSMenuItem *templateItem = [[NSMenuItem alloc] initWithTitle:file.name action:@selector(selectTemplateFile:) keyEquivalent:@""];
            templateItem.target = self;
            templateItem.representedObject = file;
            [self.templatesPopUp.menu addItem:templateItem];
            if (self.lastItem && [self.lastItem.title isEqualToString:templateItem.title]) {
                itemToSelect = templateItem;
            }
        }
        [self.templatesPopUp.menu addItem:[NSMenuItem separatorItem]];
    }
    NSMenuItem *refreshItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Refresh", nil) action:@selector(loadTemplates:) keyEquivalent:@""];
    refreshItem.target = self;
    [self.templatesPopUp.menu addItem:refreshItem];
    NSMenuItem *openFolderItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Open Templates Folder", nil) action:@selector(openTemplatesFolder:) keyEquivalent:@""];
    openFolderItem.target = self;
    [self.templatesPopUp.menu addItem:openFolderItem];
    [self.templatesPopUp selectItem:itemToSelect];
    self.templates = templates;
    self.lastItem = itemToSelect;
}

- (void)noTemplate:(id __unused)sender {
    self.selectedFile = nil;
    [self setRootNode:nil error:nil];
    self.lastItem = nil;
}

- (void)selectTemplateFile:(id)sender {
    self.selectedFile = [sender representedObject];
    [self rerunTemplate];
    self.lastItem = sender;
}

- (void)rerunTemplate {
    [self rerunTemplateWithController:self.controller];
}

- (void)rerunTemplateWithController:(HFController *)controller {
    HFASSERT(controller != nil);
    _controller = controller;
    if (!self.selectedFile) {
        return;
    }
    NSString *errorMessage = nil;
    HFTemplateNode *node = [self.templateController evaluateScript:self.selectedFile.path forController:controller error:&errorMessage];
    [self setRootNode:node error:errorMessage];
}

- (id)outlineView:(NSOutlineView * __unused)outlineView child:(NSInteger)index ofItem:(id)item {
    HFTemplateNode *node = item != nil ? item : self.node;
    return [node.children objectAtIndex:index];
}

- (NSInteger)outlineView:(NSOutlineView * __unused)outlineView numberOfChildrenOfItem:(id)item {
    HFTemplateNode *node = item != nil ? item : self.node;
    return node.children.count;
}

- (BOOL)outlineView:(NSOutlineView * __unused)outlineView isItemExpandable:(id)item {
    HFTemplateNode *node = item;
    return node.isGroup;
}

- (id)outlineView:(NSOutlineView * __unused)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item {
    HFTemplateNode *node = item;
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
    [self.outlineView reloadData];
}

- (NSColor *)selectionColor {
    NSColor *color = [NSColor lightGrayColor];
    NSData *colorData = [[NSUserDefaults standardUserDefaults] objectForKey:@"BinaryTemplateSelectionColor"];
    if (colorData && [colorData isKindOfClass:[NSData class]]) {
        NSColor *tempColor = [NSUnarchiver unarchiveObjectWithData:colorData];
        if (tempColor && [tempColor isKindOfClass:[NSColor class]]) {
            color = tempColor;
        }
    }
    return color;
}

- (void)updateSelectionColor {
    if (self.colorRange) {
        self.colorRange.color = [self selectionColor];
        [self.controller colorRangesDidChange];
    }
}

- (void)updateSelectionColorRange {
    NSInteger row = self.outlineView.selectedRow;
    if (row != -1) {
        HFTemplateNode *node = [self.outlineView itemAtRow:row];
        if (!self.colorRange) {
            self.colorRange = [[HFColorRange alloc] init];
            self.colorRange.color = [self selectionColor];
            [self.controller.colorRanges addObject:self.colorRange];
        }
        self.colorRange.range = [HFRangeWrapper withRange:node.range];
        [self.controller colorRangesDidChange];
    } else if (self.colorRange) {
        [self.controller.colorRanges removeObject:self.colorRange];
        [self.controller colorRangesDidChange];
        self.colorRange = nil;
    }
}

- (void)outlineViewSelectionDidChange:(NSNotification * __unused)notification {
    [self updateSelectionColorRange];
}

- (NSMenu *)outlineView:(NSOutlineView *)sender menuForEvent:(NSEvent *)event {
    NSMenu *menu = [[NSMenu alloc] init];
    menu.autoenablesItems = NO;
    NSPoint loc = [sender convertPoint:event.locationInWindow fromView:nil];
    NSInteger row = [sender rowAtPoint:loc];
    [sender selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
    id obj = row != -1 ? [sender itemAtRow:row] : nil;
    NSMenuItem *item = [menu addItemWithTitle:NSLocalizedString(@"Jump to Field", nil) action:@selector(jumpToField:) keyEquivalent:@""];
    item.target = self;
    item.enabled = obj != nil;
    return menu;
}

- (void)jumpToField:(id __unused)sender {
    HFTemplateNode *node = [self.outlineView itemAtRow:[self.outlineView selectedRow]];
    HFRange range = HFRangeMake(node.range.location, 0);
    [self.controller setSelectedContentsRanges:@[[HFRangeWrapper withRange:range]]];
    [self.controller maximizeVisibilityOfContentsRange:range];
}

- (void)anchorTo:(NSUInteger)position {
    self.templateController.anchor = position;
    [self rerunTemplate];
    [self updateSelectionColorRange];
}

@end
