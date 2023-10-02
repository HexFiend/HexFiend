//
//  DataInspectorRepresenter.m
//  HexFiend_2
//
//  Created by peter on 5/22/09.
//  Copyright 2009 ridiculous_fish. All rights reserved.
//

#import "DataInspectorRepresenter.h"
#import "DataInspector.h"

/* NSTableColumn identifiers */
#define kInspectorTypeColumnIdentifier @"inspector_type"
#define kInspectorSubtypeColumnIdentifier @"inspector_subtype"
#define kInspectorValueColumnIdentifier @"inspected_value"
#define kInspectorSubtractButtonColumnIdentifier @"subtract_button"
#define kInspectorAddButtonColumnIdentifier @"add_button"

#define kScrollViewExtraPadding ((CGFloat)2.)

#define INVALID_EDITING_BYTE_COUNT NSUIntegerMax

#define kDataInspectorUserDefaultsKey @"DataInspectorDefaults"

NSString * const DataInspectorDidChangeRowCount = @"DataInspectorDidChangeRowCount";
NSString * const DataInspectorDidDeleteAllRows = @"DataInspectorDidDeleteAllRows";

@implementation DataInspectorRepresenter

- (instancetype)init {
    self = [super init];
    inspectors = [[NSMutableArray alloc] init];
    [self loadDefaultInspectors];
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    HFASSERT([coder allowsKeyedCoding]);
    [super encodeWithCoder:coder];
    [coder encodeObject:inspectors forKey:@"HFInspectors"];
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    HFASSERT([coder allowsKeyedCoding]);
    self = [super initWithCoder:coder];
    inspectors = [coder decodeObjectForKey:@"HFInspectors"];
    return self;
}

- (void)loadDefaultInspectors {
    NSArray *defaultInspectorDictionaries = [[NSUserDefaults standardUserDefaults] objectForKey:kDataInspectorUserDefaultsKey];
    if (! defaultInspectorDictionaries) {
        DataInspector *ins = [[DataInspector alloc] init];
        [inspectors addObject:ins];
    }
    else {
        NSEnumerator *enumer = [defaultInspectorDictionaries objectEnumerator];
        NSDictionary *inspectorDictionary;
        while ((inspectorDictionary = [enumer nextObject])) {
            DataInspector *ins = [[DataInspector alloc] init];
            [ins setPropertyListRepresentation:inspectorDictionary];
            [inspectors addObject:ins];
        }
    }
}

- (void)saveDefaultInspectors {
    NSMutableArray *inspectorDictionaries = [[NSMutableArray alloc] init];
    DataInspector *inspector;
    NSEnumerator *enumer = [inspectors objectEnumerator];
    while ((inspector = [enumer nextObject])) {
        [inspectorDictionaries addObject:[inspector propertyListRepresentation]];
    }
    [[NSUserDefaults standardUserDefaults] setObject:inspectorDictionaries forKey:kDataInspectorUserDefaultsKey];
}

- (NSView *)createView {
    BOOL loaded = NO;
    NSMutableArray *topLevelObjects = [NSMutableArray array];
    loaded = [[NSBundle mainBundle] loadNibNamed:@"DataInspectorView" owner:self topLevelObjects:&topLevelObjects];
    if (! loaded || ! outletView) {
        [NSException raise:NSInternalInconsistencyException format:@"Unable to load nib named DataInspectorView"];
    }
    NSView *resultView = outletView; //want to inherit its retain here
    outletView = nil;
    [table setSelectionHighlightStyle:NSTableViewSelectionHighlightStyleNone];
    [table setRefusesFirstResponder:YES];
    [table setTarget:self];
    [table setDoubleAction:@selector(doubleClickedTable:)];
    if (@available(macOS 11.0, *)) {
        table.style = NSTableViewStyleFullWidth;
    }
    return resultView;
}

- (void)initializeView {
    [self resizeTableViewAfterChangingRowCount];
}

+ (NSPoint)defaultLayoutPosition {
    return NSMakePoint(0, (CGFloat)-.5);
}

- (NSUInteger)rowCount {
    return [inspectors count];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    USE(tableView);
    return [self rowCount];
}

/* returns the number of bytes that are selected, or NSUIntegerMax if there is more than one selection, or the selection is larger than MAX_EDITABLE_BYTE_COUNT */
- (NSInteger)selectedByteCountForEditing {
    NSArray *selectedRanges = [[self controller] selectedContentsRanges];
    if ([selectedRanges count] != 1) return INVALID_EDITING_BYTE_COUNT;
    HFRange selectedRange = [selectedRanges[0] HFRange];
    if (selectedRange.length > MAX_EDITABLE_BYTE_COUNT) return INVALID_EDITING_BYTE_COUNT;
    return ll2l(selectedRange.length);
}

- (NSAttributedString *)valueFromInspector:(DataInspector *)inspector isError:(BOOL *)outIsError{
    HFController *controller = [self controller];
    return [inspector valueForController:controller ranges:[controller selectedContentsRanges] isError:outIsError];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    USE(tableView);
    DataInspector *inspector = inspectors[row];
    NSString *ident = [tableColumn identifier];
    if ([ident isEqualToString:kInspectorTypeColumnIdentifier]) {
        return @([inspector type]);
    }
    else if ([ident isEqualToString:kInspectorSubtypeColumnIdentifier]) {
        return nil; // cell customized in willDisplayCell:
    }
    else if ([ident isEqualToString:kInspectorValueColumnIdentifier]) {
        return [self valueFromInspector:inspector isError:NULL];
    }
    else if ([ident isEqualToString:kInspectorAddButtonColumnIdentifier] || [ident isEqualToString:kInspectorSubtractButtonColumnIdentifier]) {
        return @1; //just a button
    }
    else {
        NSLog(@"Unknown column identifier %@", ident);
        return nil;
    }
}

- (void)tableView:(NSTableView *)tableView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    NSString *ident = [tableColumn identifier];
    /* This gets called after clicking on the + or - button.  If you delete the last row, then this gets called with a row >= the number of inspectors, so bail out for +/- buttons before pulling out our inspector */
    if ([ident isEqualToString:kInspectorSubtractButtonColumnIdentifier]) return;
    
    DataInspector *inspector = inspectors[row];
    if ([ident isEqualToString:kInspectorTypeColumnIdentifier]) {
        [inspector setType:[object intValue]];
        [tableView reloadData];
    }
    else if ([ident isEqualToString:kInspectorSubtypeColumnIdentifier]) {
        const NSInteger index = [object integerValue];
        HFASSERT(index >= -1 && index <= 5 && index != 3); // 3 is the separator
        if (index == 1 || index == 2) {
            inspector.endianness = index == 1 ? eEndianLittle : eEndianBig;
        } else if (index == 4 || index == 5) {
            inspector.numberBase = index == 4 ? eNumberBaseDecimal : eNumberBaseHexadecimal;
        }
        [tableView reloadData];
        [self saveDefaultInspectors];
    }
    else if ([ident isEqualToString:kInspectorValueColumnIdentifier]) {
        // Make sure to avoid modifications if the value didn't actually change,
        // otherwise the document gets marked as edited/dirty unnecessarily.
        NSAttributedString *oldValue = [self valueFromInspector:inspector isError:NULL];
        const BOOL valueChanged = ![oldValue.string isEqual:object];
        NSUInteger byteCount = [self selectedByteCountForEditing];
        if (byteCount != INVALID_EDITING_BYTE_COUNT && valueChanged) {
            unsigned char bytes[MAX_EDITABLE_BYTE_COUNT];
            memset(bytes, 0, sizeof(bytes));
            HFASSERT(byteCount <= sizeof(bytes));
            if ([inspector acceptStringValue:object replacingByteCount:byteCount intoData:bytes]) {
                HFController *controller = [self controller];
                NSArray *selectedRanges = [controller selectedContentsRanges];
                NSData *data = [[NSData alloc] initWithBytesNoCopy:bytes length:byteCount freeWhenDone:NO];
                [controller insertData:data replacingPreviousBytes:0 allowUndoCoalescing:NO];
                [controller setSelectedContentsRanges:selectedRanges]; //Hack to preserve the selection across the data insertion
            }
        }
    }
    else if ([ident isEqualToString:kInspectorAddButtonColumnIdentifier] || [ident isEqualToString:kInspectorSubtractButtonColumnIdentifier]) {
        /* Nothing to do */
    }
    else {
        NSLog(@"Unknown column identifier %@", ident);
    }
}

- (void)tableView:(NSTableView *)__unused tableView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)__unused row
{
    NSString *ident = [tableColumn identifier];
    if ([ident isEqualToString:kInspectorSubtypeColumnIdentifier]) {
        const DataInspector *inspector = inspectors[row];
        const bool allowsEndianness = (inspector.type == eInspectorTypeSignedInteger ||
                                 inspector.type == eInspectorTypeUnsignedInteger ||
                                 inspector.type == eInspectorTypeFloatingPoint);
        const bool allowsNumberBase = (inspector.type == eInspectorTypeSignedInteger ||
                                 inspector.type == eInspectorTypeUnsignedInteger);
        [cell setEnabled:allowsEndianness || allowsNumberBase];
        NSPopUpButtonCell *popUpCell = (NSPopUpButtonCell*)cell;
        HFASSERT(popUpCell.numberOfItems == 6);
        [popUpCell itemAtIndex:1].state = NSControlStateValueOff;
        [popUpCell itemAtIndex:2].state = NSControlStateValueOff;
        [popUpCell itemAtIndex:4].state = NSControlStateValueOff;
        [popUpCell itemAtIndex:5].state = NSControlStateValueOff;
        [popUpCell itemAtIndex:1].enabled = NO;
        [popUpCell itemAtIndex:2].enabled = NO;
        [popUpCell itemAtIndex:4].enabled = NO;
        [popUpCell itemAtIndex:5].enabled = NO;
        NSMutableArray *titleItems = [NSMutableArray array];
        if (allowsEndianness) {
            NSInteger endianIndex;
            if (inspector.endianness == eEndianLittle) {
                endianIndex = 1;
                [titleItems addObject:@"le"];
            } else {
                endianIndex = 2;
                [titleItems addObject:@"be"];
            }
            [popUpCell itemAtIndex:endianIndex].state = NSControlStateValueOn;
            [popUpCell itemAtIndex:1].enabled = YES;
            [popUpCell itemAtIndex:2].enabled = YES;
        }
        if (allowsNumberBase) {
            NSInteger numberBaseIndex;
            if (inspector.numberBase == eNumberBaseDecimal) {
                numberBaseIndex = 4;
                [titleItems addObject:@"dec"];
            } else {
                numberBaseIndex = 5;
                [titleItems addObject:@"hex"];
            }
            [popUpCell itemAtIndex:numberBaseIndex].state = NSControlStateValueOn;
            [popUpCell itemAtIndex:4].enabled = YES;
            [popUpCell itemAtIndex:5].enabled = YES;
        }
        NSMenuItem* titleMenuItem = [popUpCell itemAtIndex:0];
        if (titleItems.count > 1) {
            titleMenuItem.title = [titleItems componentsJoinedByString:@", "];
        } else if (titleItems.count == 1) {
            titleMenuItem.title = [titleItems objectAtIndex:0];
        } else {
            titleMenuItem.title = @"";
        }
    }
}

- (void)resizeTableViewAfterChangingRowCount {
    [table noteNumberOfRowsChanged];
    NSUInteger rowCount = [table numberOfRows];
    if (rowCount > 0) {
        NSScrollView *scrollView = [table enclosingScrollView];
        NSSize newTableViewBoundsSize = [table frame].size;
        newTableViewBoundsSize.height = NSMaxY([table rectOfRow:rowCount - 1]) - NSMinY([table bounds]);
        /* Is converting to the scroll view's coordinate system right?  It doesn't matter much because nothing is scaled except possibly the window */
        CGFloat newScrollViewHeight = [[scrollView class] frameSizeForContentSize:[table convertSize:newTableViewBoundsSize toView:scrollView]
                                                            hasHorizontalScroller:[scrollView hasHorizontalScroller]
                                                              hasVerticalScroller:[scrollView hasVerticalScroller]
                                                                       borderType:[scrollView borderType]].height + kScrollViewExtraPadding;
        [[NSNotificationCenter defaultCenter] postNotificationName:DataInspectorDidChangeRowCount object:self userInfo:@{@"height": @(newScrollViewHeight)}];
    }
}

- (void)addRow:(id)sender {
    USE(sender);
    DataInspector *x = [DataInspector dataInspectorSupplementing:inspectors];
    [inspectors insertObject:x atIndex:[table clickedRow]+1];
    [self saveDefaultInspectors];
    [self resizeTableViewAfterChangingRowCount];
}

- (void)removeRow:(id)sender {
    USE(sender);
    if ([self rowCount] == 1) {
        [[NSNotificationCenter defaultCenter] postNotificationName:DataInspectorDidDeleteAllRows object:self userInfo:nil];
    }
    else {
        NSInteger clickedRow = [table clickedRow];
        [inspectors removeObjectAtIndex:clickedRow];
        [self saveDefaultInspectors];
        [self resizeTableViewAfterChangingRowCount];
    }
}

- (IBAction)doubleClickedTable:(id)sender {
    USE(sender);
    NSInteger column = [table clickedColumn], row = [table clickedRow];
    if (self.controller.editable && column >= 0 && row >= 0 && [[[table tableColumns][column] identifier] isEqual:kInspectorValueColumnIdentifier]) {
        BOOL isError = NO;
        [self valueFromInspector:inspectors[row] isError:&isError];
        if (! isError) {
            [table editColumn:column row:row withEvent:[NSApp currentEvent] select:YES];
        }
        else {
            NSBeep();
        }
    }
}

- (BOOL)control:(NSControl *)control textShouldEndEditing:(NSText *)fieldEditor {
    USE(control);
    NSInteger row = [table editedRow];
    if (row < 0) return YES; /* paranoia */
    
    NSUInteger byteCount = [self selectedByteCountForEditing];
    if (byteCount == INVALID_EDITING_BYTE_COUNT) return NO;
    
    DataInspector *inspector = inspectors[row];
    return [inspector acceptStringValue:[fieldEditor string] replacingByteCount:byteCount intoData:NULL];
}

/* Prevent all row selection */

- (BOOL)tableView:(NSTableView *)tableView shouldSelectRow:(NSInteger)row {
    USE(tableView);
    USE(row);
    return NO;
}

- (BOOL)tableView:(NSTableView *)tableView shouldTrackCell:(NSCell *)cell forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    USE(tableView);
    USE(row);
    USE(cell);
    USE(tableColumn);
    return YES;
}

- (void)refreshTableValues {
    [table reloadData];
}

- (void)controllerDidChange:(HFControllerPropertyBits)bits {
    if (bits & (HFControllerSelectedRanges | HFControllerContentValue)) {
        [self refreshTableValues];
    }
    [super controllerDidChange:bits];
}

@end
