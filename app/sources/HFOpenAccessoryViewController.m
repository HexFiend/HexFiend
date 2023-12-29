//
//  HFOpenAccessoryViewController.m
//  HexFiend_2
//
//  Created by Kevin Wojniak on 2/2/19.
//  Copyright © 2019 ridiculous_fish. All rights reserved.
//

#import "HFOpenAccessoryViewController.h"
#import "HFExtendedAttributes.h"

@interface HFOpenAccessoryViewController () <NSTableViewDelegate, NSTableViewDataSource>

@property (weak) IBOutlet NSTableView *tableView;
@property (weak) IBOutlet NSButton *openFileButton;
@property (weak) IBOutlet NSButton *openAttributeButton;
@property BOOL openAttribute;

@property NSArray<NSString *> *names;

@end

@implementation HFOpenAccessoryViewController

- (instancetype)init {
    if ((self = [super initWithNibName:@"OpenAccessoryView" bundle:nil]) != nil) {
        (void)self.view; // load view
    }
    return self;
}

- (void)panelSelectionDidChange:(id)sender {
    NSOpenPanel *panel = sender;
    NSURL *url = panel.URL;
    if (url.isFileURL) {
        self.names = [HFExtendedAttributes attributesNamesAtPath:url.path error:nil];
    } else {
        self.names = nil;
    }
    [self.tableView reloadData];
    NSScrollView *scrollView = self.tableView.enclosingScrollView;
    [scrollView flashScrollers];
    if ([scrollView.documentView respondsToSelector:@selector(scrollToBeginningOfDocument:)]) {
        [scrollView.documentView scrollToBeginningOfDocument:nil];
    }
}

- (BOOL)panel:(id __unused)sender validateURL:(NSURL * __unused)url error:(NSError ** __unused)outError {
    if (self.openAttribute && self.tableView.numberOfSelectedRows == 0) {
        if (outError) {
            *outError = [NSError errorWithDomain:@"HFUIErrorDomain" code:-99 userInfo:@{NSLocalizedFailureReasonErrorKey: NSLocalizedString(@"Please select an extended attribute to open.", "")}];
        }
        return NO;
    }
    return YES;
}

- (NSInteger)numberOfRowsInTableView:(NSTableView * __unused)tableView {
    return self.names.count;
}

- (id)tableView:(NSTableView * __unused)tableView objectValueForTableColumn:(NSTableColumn * __unused)tableColumn row:(NSInteger)row {
    return self.names[row];
}

- (void)tableView:(NSTableView * __unused)tableView willDisplayCell:(id)cell forTableColumn:(NSTableColumn * __unused)tableColumn row:(NSInteger __unused)row {
    NSColor *enabledColor = NSColor.labelColor;
    NSColor *color = self.openAttribute ? enabledColor : NSColor.disabledControlTextColor;
    [cell setTextColor:color];
}

- (BOOL)tableView:(NSTableView * __unused)tableView shouldSelectRow:(NSInteger __unused)row {
    return self.openAttribute;
}

- (IBAction)openFileOrAttr:(id)sender {
    self.openAttribute = sender == self.openAttributeButton;
    [self.view.window makeFirstResponder:sender]; // clear focus ring on table
    [self enableOrDisableTableView];
}

- (void)enableOrDisableTableView {
    if (!self.openAttribute) {
        // disable table view
        [self.tableView deselectAll:nil];
        [self.tableView setFocusRingType:NSFocusRingTypeNone];
    } else {
        // enable table view
        [self.tableView setFocusRingType:NSFocusRingTypeDefault];
    }
    [self.tableView reloadData];
}

- (NSString *)extendedAttributeName {
    return self.openAttribute ? self.names[self.tableView.selectedRow] : nil;
}

- (void)reset {
    self.openFileButton.state = NSControlStateValueOn;
    self.openAttributeButton.state = NSControlStateValueOff;
    self.openAttribute = NO;
    [self enableOrDisableTableView];
}

@end
