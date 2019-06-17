//
//  ChooseStringEncodingWindowController.m
//  HexFiend_2
//
//  Copyright 2010 ridiculous_fish. All rights reserved.
//

#import "ChooseStringEncodingWindowController.h"
#import "BaseDataDocument.h"
#import "AppDelegate.h"
#import <HexFiend/HFEncodingManager.h>

@interface HFEncodingChoice : NSObject
@property (readwrite, copy) NSString *label;
@property (readwrite) HFStringEncoding *encoding;
@end
@implementation HFEncodingChoice
@end

@implementation ChooseStringEncodingWindowController
{
    NSArray<HFEncodingChoice*> *encodings;
    NSArray<HFEncodingChoice*> *activeEncodings;
}

- (NSString *)windowNibName {
    return @"ChooseStringEncodingDialog";
}

- (void)populateStringEncodings {
    NSMutableArray<HFEncodingChoice*> *localEncodings = [NSMutableArray array];
    NSArray *systemEncodings = [HFEncodingManager shared].systemEncodings;
    for (HFNSStringEncoding *encoding in systemEncodings) {
        HFEncodingChoice *choice = [[HFEncodingChoice alloc] init];
        choice.encoding = encoding;
        if ([encoding.name isEqualToString:encoding.identifier]) {
            choice.label = encoding.name;
        } else {
            choice.label = [NSString stringWithFormat:@"%@ (%@)", encoding.name, encoding.identifier];
        }
        [localEncodings addObject:choice];
    }
    NSSortDescriptor *descriptor = [[NSSortDescriptor alloc] initWithKey:@"label" ascending:YES];
    [localEncodings sortUsingDescriptors:@[descriptor]];
    encodings = localEncodings;
    activeEncodings = encodings;
}

- (void)awakeFromNib {
    [self populateStringEncodings];
    [tableView reloadData];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)__unused tableView
{
    return activeEncodings.count;
}

- (id)tableView:(NSTableView *)__unused tableView objectValueForTableColumn:(NSTableColumn *)__unused tableColumn row:(NSInteger)row
{
    NSString *identifier = tableColumn.identifier;
    if ([identifier isEqualToString:@"name"]) {
        return activeEncodings[row].encoding.name;
    } else if ([identifier isEqualToString:@"identifier"]) {
        return activeEncodings[row].encoding.identifier;
    } else {
        HFASSERT(0);
        return nil;
    }
}

- (void)tableViewSelectionDidChange:(NSNotification *)__unused notification
{
    NSInteger row = tableView.selectedRow;
    if (row == -1) {
        return;
    }
    /* Tell the front document (if any) and the app delegate */
    HFStringEncoding *encoding = activeEncodings[row].encoding;
    BaseDataDocument *document = [[NSDocumentController sharedDocumentController] currentDocument];
    if (document) {
        HFASSERT([document isKindOfClass:[BaseDataDocument class]]);
        [document setStringEncoding:encoding];
    }
    [(AppDelegate*)[NSApp delegate] setStringEncoding:encoding];
}

- (void)controlTextDidChange:(NSNotification * __unused)obj
{
    if (searchField.stringValue.length > 0) {
        NSMutableArray *searchedEncodings = [NSMutableArray array];
        for (HFEncodingChoice *choice in encodings) {
            if ([choice.encoding.name rangeOfString:searchField.stringValue options:NSCaseInsensitiveSearch].location != NSNotFound || [choice.encoding.identifier rangeOfString:searchField.stringValue options:NSCaseInsensitiveSearch].location != NSNotFound) {
                [searchedEncodings addObject:choice];
            }
        }
        activeEncodings = searchedEncodings;
    } else {
        activeEncodings = encodings;
    }
    [tableView reloadData];
}

@end
