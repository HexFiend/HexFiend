//
//  DataInspectorRepresenter.m
//  HexFiend_2
//
//  Created by peter on 5/22/09.
//  Copyright 2009 ridiculous_fish. All rights reserved.
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

/* The largest number of bytes that any inspector type can edit */
#define MAX_EDITABLE_BYTE_COUNT 8
#define INVALID_EDITING_BYTE_COUNT NSUIntegerMax

#define kDataInspectorUserDefaultsKey @"DataInspectorDefaults"

static BOOL isRunningOnLeopardOrLater(void) {
    return NSAppKitVersionNumber >= 860.;
}

NSString * const DataInspectorDidChangeRowCount = @"DataInspectorDidChangeRowCount";
NSString * const DataInspectorDidDeleteAllRows = @"DataInspectorDidDeleteAllRows";

/* Inspector types */
enum InspectorType_t {
    eInspectorTypeInteger,
    eInspectorTypeSignedInteger,
    eInspectorTypeFloatingPoint
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

enum InspectionStatus_t {
    eInspectionCanInspect,
    eInspectionNoData,
    eInspectionTooMuchData,
    eInspectionBadByteCount
};

static NSString *errorStringForInspectionStatus(enum InspectionStatus_t status) {
    switch (status) {
	case eInspectionNoData: return @"(select some data)";
	case eInspectionTooMuchData: return @"(select less data)";
	case eInspectionBadByteCount: return @"(select a power of 2 bytes)";
	default: return nil;
    }
}

/* A class representing a single row of the data inspector */
@interface DataInspector : NSObject {
    enum InspectorType_t inspectorType;
    enum Endianness_t endianness;
}

- (enum InspectorType_t)type;
- (void)setType:(enum InspectorType_t)type;

- (enum Endianness_t)endianness;
- (void)setEndianness:(enum Endianness_t)endianness;

- (enum InspectionStatus_t)inspectionStatusForByteCount:(unsigned long long)count;
- (id)valueForBytes:(const unsigned char *)bytes length:(NSUInteger)length;

/* Returns YES if we can replace the given number of bytes with this string value */
- (BOOL)acceptStringValue:(NSString *)value replacingByteCount:(NSUInteger)count intoData:(unsigned char *)outData;

/* returns YES if types wrapped around */
- (BOOL)incrementToNextType;

/* Get and set a property list representation, for persisting to user defaults */
- (id)propertyListRepresentation;
- (void)setPropertyListRepresentation:(id)plist;

@end

@implementation DataInspector

- (void)encodeWithCoder:(NSCoder *)coder {
    HFASSERT([coder allowsKeyedCoding]);
    [coder encodeInt32:inspectorType forKey:@"InspectorType"];
    [coder encodeInt32:endianness forKey:@"Endianness"];
}

- (id)initWithCoder:(NSCoder *)coder {
    HFASSERT([coder allowsKeyedCoding]);
    [super init];
    inspectorType = [coder decodeInt32ForKey:@"InspectorType"];
    endianness = [coder decodeInt32ForKey:@"Endianness"];
    return self;
}

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

- (NSUInteger)hash {
    return inspectorType + (endianness << 8UL);
}

- (BOOL)isEqual:(DataInspector *)him {
    if (! [him isKindOfClass:[DataInspector class]]) return NO;
    return inspectorType == him->inspectorType && endianness == him->endianness;
}

- (enum InspectionStatus_t)inspectionStatusForByteCount:(unsigned long long)count {
    switch ([self type]) {
        case eInspectorTypeInteger:
        case eInspectorTypeSignedInteger:
            /* Only allow positive powers of 2 up to 8 */
	    switch (count) {
		case 0: return eInspectionNoData;
		case 1: case 2: case 4: case 8: return eInspectionCanInspect;
		default: return (count > 8) ? eInspectionTooMuchData : eInspectionBadByteCount;
	    }
            
        case eInspectorTypeFloatingPoint:
            /* Only 4 and 8 */
	    switch (count) {
		case 0: return eInspectionNoData;
		case 4: case 8: return eInspectionCanInspect;
		default: return (count > 8) ? eInspectionTooMuchData : eInspectionBadByteCount;
	    }
        
        default:
            return NO;
    }
}

static uint64_t reverse(uint64_t val, NSUInteger amount) {
    /* Transfer amount bytes from input to output in reverse order */
    uint64_t input = val, output = 0;
    NSUInteger remaining = amount;
    while (remaining--) {
        unsigned char byte = input & 0xFF;
        output = (output << CHAR_BIT) | byte;
        input >>= CHAR_BIT;
    }
    return output;
}

static void flip(void *val, NSUInteger amount) {
    uint8_t *bytes = (uint8_t *)val;
    NSUInteger i;
    for (i = 0; i < amount / 2; i++) {
        uint8_t tmp = bytes[amount - i - 1];
        bytes[amount - i - 1] = bytes[i];
        bytes[i] = tmp;
    }
}

#define FETCH(type) type s = *(const type *)bytes;
#define FLIP(amount) if (endianness != eNativeEndianness) { flip(&s, amount); }
#define FORMAT(specifier) return [NSString stringWithFormat:specifier, s];
static id unsignedIntegerDescription(const unsigned char *bytes, NSUInteger length, enum Endianness_t endianness) {
    switch (length) {
        case 1:
        {
            FETCH(int8_t)
            FORMAT(@"%d")
        }
        case 2:
        {
            FETCH(int16_t)
            FLIP(2)
            FORMAT(@"%hi")
        }
        case 4:
        {
            FETCH(int32_t)
            FLIP(4)
            FORMAT(@"%d")
        }
        case 8:
        {
            FETCH(int64_t)
            FLIP(8)
            FORMAT(@"%qi") 

        }
        default: return nil;
    }
}

static id signedIntegerDescription(const unsigned char *bytes, NSUInteger length, enum Endianness_t endianness) {
    switch (length) {
        case 1:
        {
            FETCH(uint8_t)
            FORMAT(@"%u")
        }
        case 2:
        {
            FETCH(uint16_t)
            FLIP(2)
            FORMAT(@"%hu")
        }
        case 4:
        {
            FETCH(uint32_t)
            FLIP(4)
            FORMAT(@"%u")
        }
        case 8:
        {
            FETCH(uint64_t)
            FLIP(8)
            FORMAT(@"%qu") 
            
        }
        default: return nil;
    }
}
#undef FETCH
#undef FLIP
#undef FORMAT


static id floatingPointDescription(const unsigned char *bytes, NSUInteger length, enum Endianness_t endianness) {
    switch (length) {
        case sizeof(float):
        {
            union {
                uint32_t i;
                float f;
            } temp;
            assert(sizeof temp.f == sizeof temp.i);
            temp.i = *(const uint32_t *)bytes;
            if (endianness != eNativeEndianness) temp.i = (uint32_t)reverse(temp.i, sizeof(float));
            return [NSString stringWithFormat:@"%f", temp.f];
        }
        case sizeof(double):
        {
            union {
                uint64_t i;
                double f;
            } temp;
            assert(sizeof temp.f == sizeof temp.i);
            temp.i = *(const uint64_t *)bytes;
            if (endianness != eNativeEndianness) temp.i = reverse(temp.i, sizeof(double));
            return [NSString stringWithFormat:@"%e", temp.f];
        }
        default: return nil;
    }
}

- (id)valueForBytes:(const unsigned char *)bytes length:(NSUInteger)length {
    assert([self inspectionStatusForByteCount:length] == eInspectionCanInspect);
    switch ([self type]) {
        case eInspectorTypeInteger:
            return unsignedIntegerDescription(bytes, length, endianness);
            
        case eInspectorTypeSignedInteger:
            return signedIntegerDescription(bytes, length, endianness);
        
        case eInspectorTypeFloatingPoint:
            return floatingPointDescription(bytes, length, endianness);
            
        default:
            return nil;
    }
}

- (BOOL)incrementToNextType {
    BOOL wrapped = NO;
    if (endianness == eEndianBig) {
        endianness = eEndianLittle;
    }
    else {
        endianness = eEndianBig;
        inspectorType++;
        
        if (inspectorType > eInspectorTypeFloatingPoint) {
            inspectorType = eInspectorTypeInteger;
            wrapped = YES;
        }        
    }
    return wrapped;
}

static BOOL valueCanFitInByteCount(unsigned long long unsignedValue, NSUInteger count) {
    long long signedValue = (long long)unsignedValue;
    switch (count) {
	case 1:
	    return unsignedValue <= UINT8_MAX || (signedValue <= INT8_MAX && signedValue >= INT8_MIN);
	case 2:
	    return unsignedValue <= UINT16_MAX || (signedValue <= INT16_MAX && signedValue >= INT16_MIN);
	case 4:
	    return unsignedValue <= UINT32_MAX || (signedValue <= INT32_MAX && signedValue >= INT32_MIN);
	case 8:
	    return unsignedValue <= UINT64_MAX || (signedValue <= INT64_MAX && signedValue >= INT64_MIN);
	default:
	    return NO;
    }
}

- (BOOL)acceptStringValue:(NSString *)value replacingByteCount:(NSUInteger)count intoData:(unsigned char *)outData {
    if (inspectorType == eInspectorTypeInteger || inspectorType == eInspectorTypeSignedInteger) {
	if (! (count == 1 || count == 2 || count == 4 || count == 8)) return NO;
	
	char buffer[256];
	BOOL success = [value getCString:buffer maxLength:sizeof buffer encoding:NSASCIIStringEncoding];
	if (! success) return NO;
    
	
	errno = 0;
	char *endPtr = NULL;
	/* note that strtoull handles negative values */
	unsigned long long unsignedValue = strtoull(buffer, &endPtr, 0);
	int resultError = errno;
	
	/* Make sure we consumed some of the string */
	if (endPtr == buffer) return NO;
	
	/* Check for conversion errors (overflow, etc.) */
	if (resultError != 0) return NO;
	
	/* Now check to make sure we fit */
	if (! valueCanFitInByteCount(unsignedValue, count)) return NO;
	
	/* Actually return the bytes if requested */
	if (outData != NULL) {
	    /* Get all 8 bytes in big-endian form */
	    unsigned long long consumableValue = unsignedValue;
	    unsigned char bytes[8];
	    unsigned i = 8;
	    while (i--) {
		bytes[i] = consumableValue & 0xFF;
		consumableValue >>= 8;
	    }
	    
	    /* Now copy the last (least significant) 'count' bytes to outData in the requested endianness */
	    for (i=0; i < count; i++) {
		unsigned char byte = bytes[(8 - count + i)];
		if (endianness == eEndianBig) {
		    outData[i] = byte;
		}
		else {
		    outData[count - i - 1] = byte;
		}
	    }
	}
	
	/* Victory */
	return YES;
    }
    else if (inspectorType == eInspectorTypeFloatingPoint) {
	if (! (count == 4 || count == 8)) return NO;
	assert(sizeof(float) == 4);
	assert(sizeof(double) == 8);
	
	BOOL useFloat = (count == 4);
	
	char buffer[256];
	BOOL success = [value getCString:buffer maxLength:sizeof buffer encoding:NSASCIIStringEncoding];
	if (! success) return NO;
	
	double doubleValue = 0;
	float floatValue = 0;
	
	errno = 0;
	char *endPtr = NULL;
	if (useFloat) {
	    floatValue = strtof(buffer, &endPtr);
	}
	else {
	    doubleValue = strtod(buffer, &endPtr);
	}
	int resultError = errno;
	
	/* Make sure we consumed some of the string */
	if (endPtr == buffer) return NO;
	
	/* Check for conversion errors (overflow, etc.) */
	if (resultError != 0) return NO;
	
	if (outData != NULL) {
	    unsigned char bytes[8];
	    if (useFloat) {
		memcpy(bytes, &floatValue, sizeof floatValue);
	    }
	    else {
		memcpy(bytes, &doubleValue, sizeof doubleValue);
	    }
	    
	    /* Now copy the first 'count' bytes to outData in the requested endianness.  This is different from the integer case - there we always work big-endian because we support more different byteCounts, but here we work in the native endianness because there's no simple way to convert a float or double to big endian form */
	    NSUInteger i;
	    for (i=0; i < count; i++) {
		if (endianness == eNativeEndianness) {
		    outData[i] = bytes[i];
		}
		else {
		    outData[count - i - 1] = bytes[i];
		}
	    }
	}
	
	/* Return triumphantly! */
	return YES;
    }
    else {
	/* Unknown inspector type */
	return NO;
    }
}

- (id)propertyListRepresentation {
    return [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:inspectorType], @"InspectorType", [NSNumber numberWithInt:endianness], @"Endianness", nil];
}

- (void)setPropertyListRepresentation:(id)plist {
    inspectorType = [[plist objectForKey:@"InspectorType"] intValue];
    endianness = [[plist objectForKey:@"Endianness"] intValue];
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

- (void)dealloc {
    [inspectors release];
    [super dealloc];
}

- (void)encodeWithCoder:(NSCoder *)coder {
    HFASSERT([coder allowsKeyedCoding]);
    [super encodeWithCoder:coder];
    [coder encodeObject:inspectors forKey:@"HFInspectors"];
}

- (id)initWithCoder:(NSCoder *)coder {
    HFASSERT([coder allowsKeyedCoding]);
    [super initWithCoder:coder];
    inspectors = [[coder decodeObjectForKey:@"HFInspectors"] retain];
    return self;
}

- (void)loadDefaultInspectors {
    NSArray *defaultInspectorDictionaries = [[NSUserDefaults standardUserDefaults] objectForKey:kDataInspectorUserDefaultsKey];
    if (! defaultInspectorDictionaries) {
        DataInspector *ins = [[DataInspector alloc] init];
        [inspectors addObject:ins];
        [ins release];
    }
    else {
        NSEnumerator *enumer = [defaultInspectorDictionaries objectEnumerator];
        NSDictionary *inspectorDictionary;
        while ((inspectorDictionary = [enumer nextObject])) {
            DataInspector *ins = [[DataInspector alloc] init];
            [ins setPropertyListRepresentation:inspectorDictionary];
            [inspectors addObject:ins];
            [ins release];            
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
    [inspectorDictionaries release];
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
    [table setRefusesFirstResponder:YES];
    [table setTarget:self];
    [table setDoubleAction:@selector(doubleClickedTable:)];    
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
    HFRange selectedRange = [[selectedRanges objectAtIndex:0] HFRange];
    if (selectedRange.length > MAX_EDITABLE_BYTE_COUNT) return INVALID_EDITING_BYTE_COUNT;
    return ll2l(selectedRange.length);
}

static NSAttributedString *inspectionError(NSString *s) {
    NSMutableParagraphStyle *paragraphStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
    [paragraphStyle setMinimumLineHeight:(CGFloat)16.];
    NSAttributedString *result = [[NSAttributedString alloc] initWithString:s attributes:[NSDictionary dictionaryWithObjectsAndKeys:[NSColor disabledControlTextColor], NSForegroundColorAttributeName, [NSFont controlContentFontOfSize:11], NSFontAttributeName, paragraphStyle, NSParagraphStyleAttributeName, nil]];
    [paragraphStyle release];
    return [result autorelease];
}

- (id)valueFromInspector:(DataInspector *)inspector isError:(BOOL *)outIsError{
    HFController *controller = [self controller];
    NSArray *selectedRanges = [controller selectedContentsRanges];
    if ([selectedRanges count] != 1) {
	if (outIsError) *outIsError = YES;
	return inspectionError(@"(select a contiguous range)");
    }

    HFRange selectedRange = [[selectedRanges objectAtIndex:0] HFRange];
    enum InspectionStatus_t inspectionStatus = [inspector inspectionStatusForByteCount:selectedRange.length];
    if (inspectionStatus != eInspectionCanInspect) {
	if (outIsError) *outIsError = YES;
	return inspectionError(errorStringForInspectionStatus(inspectionStatus));
    }
    
    NSData *selection = [controller dataForRange:selectedRange];
    [selection retain];
    const unsigned char *bytes = [selection bytes];
    id result = [inspector valueForBytes:bytes length:ll2l(selectedRange.length)];
    [selection release]; //keep it alive for GC
    if (outIsError) *outIsError = NO;
    return result;
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
        return [self valueFromInspector:inspector isError:NULL];
    }
    else if ([ident isEqualToString:kInspectorAddButtonColumnIdentifier] || [ident isEqualToString:kInspectorSubtractButtonColumnIdentifier]) {
        return [NSNumber numberWithInt:1]; //just a button
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
	NSUInteger byteCount = [self selectedByteCountForEditing];
	if (byteCount != INVALID_EDITING_BYTE_COUNT) {
	    HFASSERT(byteCount <= MAX_EDITABLE_BYTE_COUNT);
	    unsigned char bytes[MAX_EDITABLE_BYTE_COUNT];
	    if ([inspector acceptStringValue:object replacingByteCount:byteCount intoData:bytes]) {
		HFController *controller = [self controller];
		NSArray *selectedRanges = [controller selectedContentsRanges];
		NSData *data = [[NSData alloc] initWithBytes:bytes length:byteCount];
		[controller insertData:data replacingPreviousBytes:0 allowUndoCoalescing:NO];
		[data release];
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
        [[NSNotificationCenter defaultCenter] postNotificationName:DataInspectorDidChangeRowCount object:self userInfo:[NSDictionary dictionaryWithObject:[NSNumber numberWithDouble:newScrollViewHeight] forKey:@"height"]];
    }
}

- (void)addRow:(id)sender {
    USE(sender);
    DataInspector *ins = [[DataInspector alloc] init];
    /* Try to add an inspector that we don't already have */
    NSMutableSet *existingInspectors = [[NSMutableSet alloc] initWithArray:inspectors];
    while ([existingInspectors containsObject:ins]) {
	BOOL wrapped = [ins incrementToNextType];
	if (wrapped) break;
    }
    [existingInspectors release];
    
    NSInteger clickedRow = [table clickedRow];
    [inspectors insertObject:ins atIndex:clickedRow + 1];
    [ins release];
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
    if (column >= 0 && row >= 0 && [[[[table tableColumns] objectAtIndex:column] identifier] isEqual:kInspectorValueColumnIdentifier]) {
	BOOL isError;
	[self valueFromInspector:[inspectors objectAtIndex:row] isError:&isError];
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
    
    DataInspector *inspector = [inspectors objectAtIndex:row];
    return [inspector acceptStringValue:[fieldEditor string] replacingByteCount:byteCount intoData:NULL];
}


/* Prevent all row selection */

- (BOOL)tableView:(NSTableView *)tableView shouldSelectRow:(NSInteger)row {
    /* since shouldTrackCell is only available on 10.5, fall back to crappier behavior on 10.4 */
    USE(tableView);
    USE(row);
    return ! isRunningOnLeopardOrLater();
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

@implementation DataInspectorPlusMinusButtonCell

- (id)initWithCoder:(NSCoder *)coder {
    [super initWithCoder:coder];
    [self setBezelStyle:NSRoundRectBezelStyle];
    return self;
}

- (void)drawDataInspectorTitleWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
    const BOOL isPlus = [[self title] isEqual:@"+"];
    const unsigned char grayColor = 0x73;
    const unsigned char alpha = 0xFF;
#if __BIG_ENDIAN__
    const unsigned short X = (grayColor << 8) | alpha ;
#else
    const unsigned short X = (alpha << 8) | grayColor;
#endif
    const NSUInteger bytesPerPixel = sizeof X;
    const unsigned short plusData[] = {
	0,0,0,X,X,0,0,0,
	0,0,0,X,X,0,0,0,
	0,0,0,X,X,0,0,0,
	X,X,X,X,X,X,X,X,
	X,X,X,X,X,X,X,X,
	0,0,0,X,X,0,0,0,
	0,0,0,X,X,0,0,0,
	0,0,0,X,X,0,0,0
    };
    
    const unsigned short minusData[] = {
	0,0,0,0,0,0,0,0,
	0,0,0,0,0,0,0,0,
	0,0,0,0,0,0,0,0,
	X,X,X,X,X,X,X,X,
	X,X,X,X,X,X,X,X,
	0,0,0,0,0,0,0,0,
	0,0,0,0,0,0,0,0,
	0,0,0,0,0,0,0,0
    };
    
    const unsigned char * const bitmapData = (const unsigned char *)(isPlus ? plusData : minusData);
    
    NSInteger width = 8, height = 8;
    assert(width * height * bytesPerPixel == sizeof plusData);
    assert(width * height * bytesPerPixel == sizeof minusData);
    NSRect bitmapRect = NSMakeRect(NSMidX(cellFrame) - width/2, NSMidY(cellFrame) - height/2, width, height);
    bitmapRect = [controlView centerScanRect:bitmapRect];

    CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceGenericGray);
    CGDataProviderRef provider = CGDataProviderCreateWithData(NULL, bitmapData, width * height * bytesPerPixel, NULL);
    CGImageRef image = CGImageCreate(width, height, CHAR_BIT, bytesPerPixel * CHAR_BIT, bytesPerPixel * width, space, kCGImageAlphaPremultipliedLast, provider, NULL, YES, kCGRenderingIntentDefault);
    CGDataProviderRelease(provider);
    CGColorSpaceRelease(space);
    [[NSGraphicsContext currentContext] setCompositingOperation:NSCompositeSourceOver];
    CGContextDrawImage([[NSGraphicsContext currentContext] graphicsPort], *(CGRect *)&bitmapRect, image);
    CGImageRelease(image);
}

- (NSRect)drawTitle:(NSAttributedString*)title withFrame:(NSRect)frame inView:(NSView*)controlView {
    /* Defeat title drawing by doing nothing */
    USE(title);
    USE(frame);
    USE(controlView);
    return NSZeroRect;
}

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
    [super drawWithFrame:cellFrame inView:controlView];
    [self drawDataInspectorTitleWithFrame:cellFrame inView:controlView];

}

@end

@implementation DataInspectorTableView

- (void)highlightSelectionInClipRect:(NSRect)clipRect {
    USE(clipRect);
}

@end
