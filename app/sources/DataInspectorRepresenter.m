//
//  DataInspectorRepresenter.m
//  HexFiend_2
//
//  Created by peter on 5/22/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "DataInspectorRepresenter.h"

/* NSTableColumn identifiers */
#define kInspectorTypeColumnIdentifier @"inspector_type"
#define kInspectorSubtypeColumnIdentifier @"inspector_subtype"
#define kInspectorValueColumnIdentifier @"inspected_value"
#define kInspectorSubtractButtonColumnIdentifier @"subtract_button"
#define kInspectorAddButtonColumnIdentifier @"add_button"

#define kScrollViewExtraPadding ((CGFloat)2.)

/* Declaration of SnowLeopard only property so we can build on Leopard */
#define NSTableViewSelectionHighlightStyleNone (-1)

NSString * const DataInspectorDidChangeSize = @"DataInspectorDidChangeSize";

/* Inspector types */
enum InspectorType_t {
    eInspectorTypeInteger,
    eInspectorTypeFloatingPoint,
    eInspectorTypeColor
};

enum Endianness_t {
    eEndianBig,
    eEndianLittle,

#if __BIG_ENDIAN__
    eNativeEndianness = eEndianBig
#else
    eNativeEndianness = eEndianLittle
#endif
};

/* A class representing a single row of the data inspector */
@interface DataInspector : NSObject {
    enum InspectorType_t inspectorType;
    enum Endianness_t endianness;
}

- (enum InspectorType_t)type;
- (void)setType:(enum InspectorType_t)type;

- (enum Endianness_t)endianness;
- (void)setEndianness:(enum Endianness_t)endianness;

- (BOOL)canDisplayDataForByteCount:(unsigned long long)count;
- (id)valueForBytes:(const unsigned char *)bytes length:(NSUInteger)length;

@end

@implementation DataInspector


- (void)setType:(enum InspectorType_t)type {
    inspectorType = type;
}

- (enum InspectorType_t)type {
    return inspectorType;
}

- (void)setEndianness:(enum Endianness_t)end {
    endianness = end;
}

- (enum Endianness_t)endianness {
    return endianness;
}

- (BOOL)canDisplayDataForByteCount:(unsigned long long)count {
    switch ([self type]) {
        case eInspectorTypeInteger:
            /* Only allow positive powers of 2 up to 8 */
            return count > 0 && count <= 8 && ! (count & (count - 1));
            
        case eInspectorTypeFloatingPoint:
            /* Only 4 and 8 */
            return count == 4 || count == 8;
        
        case eInspectorTypeColor:
        default:
            return NO;
    }
}

static id integerDescription(const unsigned char *bytes, NSUInteger length) {
    unsigned long long s = 0;
    switch (length) {
        case 1:
        {
            s = *(const uint8_t *)bytes;
            break;

        }
        case 2:
        {
            s = *(const uint16_t *)bytes;
            break;
        }
        case 4:
        {
            s = *(const uint32_t *)bytes;
            break;
        }
        case 8:
        {
            s = *(const uint64_t *)bytes;
            break;
        }
        default: return nil;
    }
    return [NSString stringWithFormat:@"%lld", s];
}

static id floatingPointDescription(const unsigned char *bytes, NSUInteger length) {
    switch (length) {
        case 4:
        {
            float s = *(const float *)bytes;
            return [NSString stringWithFormat:@"%f", s];
        }
        case 8:
        {
            double s = *(const double *)bytes;
            return [NSString stringWithFormat:@"%f", s];
        }
        default: return nil;
    }
}

- (id)valueForBytes:(const unsigned char *)bytes length:(NSUInteger)length {
    assert([self canDisplayDataForByteCount:length]);
    switch ([self type]) {
        case eInspectorTypeInteger:
            return integerDescription(bytes, length);
        
        case eInspectorTypeFloatingPoint:
            return floatingPointDescription(bytes, length);
            
        default:
            return nil;
    }
}

@end

@implementation DataInspectorScrollView

- (void)drawDividerWithClip:(NSRect)clipRect {
    [[NSColor lightGrayColor] set];
    NSRect bounds = [self bounds];
    NSRect lineRect = bounds;
    lineRect.size.height = 1;
    NSRectFill(NSIntersectionRect(lineRect, clipRect));
}

- (void)drawRect:(NSRect)rect {
    [[NSColor colorWithCalibratedWhite:(CGFloat).91 alpha:1] set];
    NSRectFill(rect);
    [self drawDividerWithClip:rect];
}

@end

@implementation DataInspectorRepresenter

- (id)init {
    [super init];
    inspectors = [[NSMutableArray alloc] init];
    [self loadDefaultInspectors];
    return self;
}

- (void)loadDefaultInspectors {
    DataInspector *ins = [[DataInspector alloc] init];
    [inspectors addObject:ins];
    [ins release];
}

- (NSView *)createView {
    BOOL loaded = [NSBundle loadNibNamed:@"DataInspectorView" owner:self];
    if (! loaded || ! outletView) {
        [NSException raise:NSInternalInconsistencyException format:@"Unable to load nib named DataInspectorView"];
    }
    NSView *resultView = outletView; //want to inherit its retain here
    outletView = nil;
    if ([table respondsToSelector:@selector(setSelectionHighlightStyle:)]) {
        [table setSelectionHighlightStyle:NSTableViewSelectionHighlightStyleNone];
    }
    [table setBackgroundColor:[NSColor colorWithCalibratedWhite:(CGFloat).91 alpha:1]];
    return resultView;
}

+ (NSPoint)defaultLayoutPosition {
    return NSMakePoint(0, (CGFloat)-.5);
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return [inspectors count];
}

static NSAttributedString *notApplicableString(void) {
    static NSAttributedString *string;
    if (! string) {
        string = [[NSAttributedString alloc] initWithString:@"(n/a)" attributes:[NSDictionary dictionaryWithObjectsAndKeys:[NSColor disabledControlTextColor], NSForegroundColorAttributeName, nil]];
    }
    return string;
}

- (id)valueFromInspector:(DataInspector *)inspector {
    id resultValue = nil;
    HFController *controller = [self controller];
    NSArray *selectedRanges = [controller selectedContentsRanges];
    if ([selectedRanges count] == 1) {
        HFRange selectedRange = [[selectedRanges objectAtIndex:0] HFRange];
        if ([inspector canDisplayDataForByteCount:selectedRange.length]) {
            NSData *selection = [controller dataForRange:selectedRange];
            [selection retain];
            const unsigned char *bytes = [selection bytes];
            resultValue = [inspector valueForBytes:bytes length:ll2l(selectedRange.length)];
            [selection release]; //keep it alive for GC
        }
    }
    if (! resultValue) {
        /* Show n/a */
        resultValue = notApplicableString();
    }
    return resultValue;    
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    USE(tableView);
    DataInspector *inspector = [inspectors objectAtIndex:row];
    NSString *ident = [tableColumn identifier];
    if ([ident isEqualToString:kInspectorTypeColumnIdentifier]) {
        return [NSNumber numberWithInt:[inspector type]];
    }
    else if ([ident isEqualToString:kInspectorSubtypeColumnIdentifier]) {
        return [NSNumber numberWithInt:[inspector endianness]];
    }
    else if ([ident isEqualToString:kInspectorValueColumnIdentifier]) {
        return [self valueFromInspector:inspector];
    }
    else if ([ident isEqualToString:kInspectorAddButtonColumnIdentifier]) {
        return [NSNumber numberWithInt:1]; //just a button
    }
    else {
        NSLog(@"Unknown column identifier %@", ident);
        return nil;
    }
}

- (void)tableView:(NSTableView *)tableView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    NSString *ident = [tableColumn identifier];
    DataInspector *inspector = [inspectors objectAtIndex:row];
    if ([ident isEqualToString:kInspectorTypeColumnIdentifier]) {
        [inspector setType:[object intValue]];
        [tableView reloadData];
    }
    else if ([ident isEqualToString:kInspectorSubtypeColumnIdentifier]) {
        [inspector setEndianness:[object intValue]];
        [tableView reloadData];
    }
    else if ([ident isEqualToString:kInspectorValueColumnIdentifier]) {
        
    }
    else if ([ident isEqualToString:kInspectorAddButtonColumnIdentifier]) {
        /* Nothing to do */
    }
    else {
        NSLog(@"Unknown column identifier %@", ident);
    }
    
}

- (void)addRow:(id)sender {
    DataInspector *ins = [[DataInspector alloc] init];
    NSInteger clickedRow = [table clickedRow];
    [inspectors insertObject:ins atIndex:clickedRow + 1];
    [ins release];
    [table noteNumberOfRowsChanged];
    NSScrollView *scrollView = [table enclosingScrollView];
    CGFloat newScrollViewHeight = [[scrollView class] frameSizeForContentSize:[table frame].size
                                                        hasHorizontalScroller:[scrollView hasHorizontalScroller]
                                                          hasVerticalScroller:[scrollView hasVerticalScroller]
                                                                   borderType:[scrollView borderType]].height + kScrollViewExtraPadding;
    [[NSNotificationCenter defaultCenter] postNotificationName:DataInspectorDidChangeSize object:self userInfo:[NSDictionary dictionaryWithObject:[NSNumber numberWithDouble:newScrollViewHeight] forKey:@"height"]];
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
