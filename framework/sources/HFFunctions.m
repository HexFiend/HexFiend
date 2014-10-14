#import <HexFiend/HFFunctions.h>
#import <HexFiend/HFController.h>

#import "HFFunctions_Private.h"

#ifndef NDEBUG
//#define USE_CHUD 1
#endif

#ifndef USE_CHUD
#define USE_CHUD 0
#endif

#if USE_CHUD
#import <CHUD/CHUD.h>
#endif

NSImage *HFImageNamed(NSString *name) {
    HFASSERT(name != NULL);
    NSImage *image = [NSImage imageNamed:name];
    if (image == NULL) {
        NSString *imagePath = [[NSBundle bundleForClass:[HFController class]] pathForResource:name ofType:@"tiff"];
        if (! imagePath) {
            NSLog(@"Unable to find image named %@.tiff", name);
        }
        else {
            image = [[NSImage alloc] initByReferencingFile:imagePath];
            if (image == nil || ! [image isValid]) {
                NSLog(@"Couldn't load image at path %@", imagePath);
                [image release];
                image = nil;
            }
            else {
                [image setName:name];
            }
        }
    }
    return image;
}

@implementation HFRangeWrapper

- (HFRange)HFRange { return range; }

+ (HFRangeWrapper *)withRange:(HFRange)range {
    HFRangeWrapper *result = [[self alloc] init];
    result->range = range;
    return [result autorelease];
}

+ (NSArray *)withRanges:(const HFRange *)ranges count:(NSUInteger)count {
    HFASSERT(count == 0 || ranges != NULL);
    NSUInteger i;
    NSArray *result;
    NEW_ARRAY(HFRangeWrapper *, wrappers, count);
    for (i=0; i < count; i++) wrappers[i] = [self withRange:ranges[i]];
    result = [NSArray arrayWithObjects:wrappers count:count];
    FREE_ARRAY(wrappers);
    return result;
}

- (BOOL)isEqual:(id)obj {
    if (! [obj isKindOfClass:[HFRangeWrapper class]]) return NO;
    else return HFRangeEqualsRange(range, [obj HFRange]);
}

- (NSUInteger)hash {
    return (NSUInteger)(range.location + (range.length << 16));
}

- (id)copyWithZone:(NSZone *)zone {
    USE(zone);
    return [self retain];
}

- (NSString *)description {
    return HFRangeToString(range);
}

static int hfrange_compare(const void *ap, const void *bp) {
    const HFRange *a = ap;
    const HFRange *b = bp;
    if (a->location < b->location) return -1;
    else if (a->location > b->location) return 1;
    else if (a->length < b->length) return -1;
    else if (a->length > b->length) return 1;
    else return 0;
}

+ (NSArray *)organizeAndMergeRanges:(NSArray *)inputRanges {
    HFASSERT(inputRanges != NULL);
    NSUInteger leading = 0, trailing = 0, length = [inputRanges count];
    if (length == 0) return @[];
    else if (length == 1) return [NSArray arrayWithArray:inputRanges];
    
    NEW_ARRAY(HFRange, ranges, length);
    [self getRanges:ranges fromArray:inputRanges];
    qsort(ranges, length, sizeof ranges[0], hfrange_compare);
    leading = 0;
    while (leading < length) {
        leading++;
        if (leading < length) {
            HFRange leadRange = ranges[leading], trailRange = ranges[trailing];
            if (HFIntersectsRange(leadRange, trailRange) || HFMaxRange(leadRange) == trailRange.location || HFMaxRange(trailRange) == leadRange.location) {
                ranges[trailing] = HFUnionRange(leadRange, trailRange);
            }
            else {
                trailing++;
                ranges[trailing] = ranges[leading];
            }
        }
    }
    NSArray *result = [HFRangeWrapper withRanges:ranges count:trailing + 1];
    FREE_ARRAY(ranges);
    return result;
}

+ (void)getRanges:(HFRange *)ranges fromArray:(NSArray *)array {
    HFASSERT(ranges != NULL || [array count] == 0);
    if (ranges) {
        FOREACH(HFRangeWrapper*, wrapper, array) *ranges++ = [wrapper HFRange];
    }
}

@end

@implementation HFRangeSet
// HFRangeSet is implemented as a CFMutableArray of uintptr_t "fenceposts". The array
// is even in length, sorted, duplicate free, and considered to include the ranges
// [array[0], array[1]), [array[2], array[3]), ..., [array[2n], array[2n+1])

CFComparisonResult uintptrComparator(const void *val1, const void *val2, void *context) {
    (void)context;
    uintptr_t a = (uintptr_t)val1;
    uintptr_t b = (uintptr_t)val2;
    if(a < b) return kCFCompareLessThan;
    if(a > b) return kCFCompareGreaterThan;
    return kCFCompareEqualTo;
}

static void HFRangeSetAddRange(CFMutableArrayRef array, uintptr_t a, uintptr_t b) {
    CFIndex count = CFArrayGetCount(array);
    assert(a < b); assert(count % 2 == 0);
    CFIndex idxa = CFArrayBSearchValues(array, CFRangeMake(0, count), (void*)a, uintptrComparator, NULL);
    CFIndex idxb = CFArrayBSearchValues(array, CFRangeMake(0, count), (void*)b, uintptrComparator, NULL);

    const void *x[2] = { (void*)a, (void*)b };
    if(idxa >= count) {
        CFArrayReplaceValues(array, CFRangeMake(count, 0), x, 2);
        return;
    }
    if(idxb == 0) {
        CFArrayReplaceValues(array, CFRangeMake(0, 0), x, 2);
        return;
    }

    // Clear fenceposts strictly between 'a' and 'b', and then possibly
    // add 'a' or 'b' as fenceposts.
    CFIndex cutloc = (uintptr_t)CFArrayGetValueAtIndex(array, idxa) == a ? idxa+1 : idxa;
    CFIndex cutlen = idxb - cutloc;
    
    bool inca = cutloc % 2 == 0; // Include 'a' if it would begin an included range
    bool incb = (count - cutlen + inca) % 2 == 1; // The set must be even, which tells us about 'b'.
    
    CFArrayReplaceValues(array, CFRangeMake(cutloc, cutlen), x+inca, inca+incb);
    assert(CFArrayGetCount(array) % 2 == 0);
}

static void HFRangeSetRemoveRange(CFMutableArrayRef array, uintptr_t a, uintptr_t b) {
    CFIndex count = CFArrayGetCount(array);
    assert(a < b); assert(count % 2 == 0);
    CFIndex idxa = CFArrayBSearchValues(array, CFRangeMake(0, count), (void*)a, uintptrComparator, NULL);
    CFIndex idxb = CFArrayBSearchValues(array, CFRangeMake(0, count), (void*)b, uintptrComparator, NULL);
    if(idxa >= count || idxb == 0) return;

    // Remove fenceposts strictly between 'a' and 'b', and then possibly
    // add 'a' or 'b' as fenceposts.
    CFIndex cutloc = (uintptr_t)CFArrayGetValueAtIndex(array, idxa) == a ? idxa+1 : idxa;
    CFIndex cutlen = idxb - cutloc;
    
    bool inca = cutloc % 2 == 1; // Include 'a' if it would end an included range
    bool incb = (count - cutlen + inca) % 2 == 1; // The set must be even, which tells us about 'b'.
    
    const void *x[2] = { (void*)a, (void*)b };
    CFArrayReplaceValues(array, CFRangeMake(cutloc, cutlen), x+inca, inca+incb);
    assert(CFArrayGetCount(array) % 2 == 0);
}

static void HFRangeSetToggleRange(CFMutableArrayRef array, uintptr_t a, uintptr_t b) {
    CFIndex count = CFArrayGetCount(array);
    assert(a < b); assert(count % 2 == 0);
    
    // In the fencepost representation, simply toggling the existence of
    // fenceposts 'a' and 'b' achieves symmetric difference.
    
    CFIndex idxa = CFArrayBSearchValues(array, CFRangeMake(0, count), (void*)a, uintptrComparator, NULL);
    if((uintptr_t)CFArrayGetValueAtIndex(array, idxa) == a) {
        CFArrayRemoveValueAtIndex(array, idxa);
    } else {
        CFArrayInsertValueAtIndex(array, idxa, (void*)a);
    }

    CFIndex idxb = CFArrayBSearchValues(array, CFRangeMake(0, count), (void*)b, uintptrComparator, NULL);
    if((uintptr_t)CFArrayGetValueAtIndex(array, idxb) == b) {
        CFArrayRemoveValueAtIndex(array, idxb);
    } else {
        CFArrayInsertValueAtIndex(array, idxb, (void*)b);
    }
    
    assert(CFArrayGetCount(array) % 2 == 0);
}

static BOOL HFRangeSetContainsAllRange(CFMutableArrayRef array, uintptr_t a, uintptr_t b) {
    CFIndex count = CFArrayGetCount(array);
    assert(a < b); assert(count % 2 == 0);
    CFIndex idxa = CFArrayBSearchValues(array, CFRangeMake(0, count), (void*)a, uintptrComparator, NULL);
    CFIndex idxb = CFArrayBSearchValues(array, CFRangeMake(0, count), (void*)b, uintptrComparator, NULL);
    if(idxa >= count || idxb == 0) return NO;
    
    // Optimization: if the indexes are far enough apart, then obviouly there's a gap.
    if(idxb - idxa >= 2) return NO;

    // The first fencepost >= 'b' must end an include range, a must be in the same range.
    return idxb%2 == 1 && idxa == ((uintptr_t)CFArrayGetValueAtIndex(array, idxa) == a ? idxb-1 : idxb);
}

static BOOL HFRangeSetOverlapsAnyRange(CFMutableArrayRef array, uintptr_t a, uintptr_t b) {
    CFIndex count = CFArrayGetCount(array);
    assert(a < b); assert(count % 2 == 0);
    CFIndex idxa = CFArrayBSearchValues(array, CFRangeMake(0, count), (void*)a, uintptrComparator, NULL);
    CFIndex idxb = CFArrayBSearchValues(array, CFRangeMake(0, count), (void*)b, uintptrComparator, NULL);
    if(idxa >= count || idxb == 0) return NO;
    
    // Optimization: if the indexes are far enough apart, then obviouly there's overlap.
    if(idxb - idxa >= 2) return YES;
    
    if((uintptr_t)CFArrayGetValueAtIndex(array, idxa) == a) {
        // 'a' is an included fencepost, or instead 'b' makes it past an included fencepost.
        return idxa % 2 == 0 || b > (uintptr_t)CFArrayGetValueAtIndex(array, idxa+1);
    } else {
        // 'a' lies in an included range, or instead 'b' makes it past an included fencepost.
        return  idxa % 2 == 1 || b > (uintptr_t)CFArrayGetValueAtIndex(array, idxa);
    }
}

- (instancetype)init {
    if(!(self = [super init])) return nil;
    array = CFArrayCreateMutable(kCFAllocatorDefault, 0, NULL);
    return self;
}

- (void)dealloc {
    CFRelease(array);
    [super dealloc];
}

+ (HFRangeSet *)withRange:(HFRange)range {
    HFRangeSet *newSet = [[[HFRangeSet alloc] init] autorelease];
    if(range.length > 0) {
        CFArrayAppendValue(newSet->array, (void*)ll2p(range.location));
        CFArrayAppendValue(newSet->array, (void*)ll2p(HFMaxRange(range)));
    }
    return newSet;
}

+ (HFRangeSet *)withRanges:(const HFRange *)ranges count:(NSUInteger)count {
    // FIXME: Stub. Don't rely on the thing we're replacing!
    return [HFRangeSet withRangeWrappers:[HFRangeWrapper withRanges:ranges count:count]];
}

+ (HFRangeSet *)withRangeWrappers:(NSArray *)ranges {
    HFRangeSet *newSet = [[[HFRangeSet alloc] init] autorelease];
    FOREACH(HFRangeWrapper *, wrapper, [HFRangeWrapper organizeAndMergeRanges:ranges]) {
        if(wrapper->range.length > 0) {
            CFArrayAppendValue(newSet->array, (void*)ll2p(wrapper->range.location));
            CFArrayAppendValue(newSet->array, (void*)ll2p(HFMaxRange(wrapper->range)));
        }
    }
    return newSet;
}

+ (HFRangeSet *)withRangeSet:(HFRangeSet *)rangeSet {
    return [[rangeSet copy] autorelease];
}

+ (HFRangeSet *)complementOfRangeSet:(HFRangeSet *)rangeSet inRange:(HFRange)range {
    if(range.length <= 0) {
        // Complement in empty is... empty!
        return [HFRangeSet withRange:HFZeroRange];
    }
    uintptr_t a = ll2p(range.location);
    uintptr_t b = ll2p(HFMaxRange(range));
    CFIndex count = CFArrayGetCount(rangeSet->array);
    CFIndex idxa = CFArrayBSearchValues(rangeSet->array, CFRangeMake(0, count), (void*)a, uintptrComparator, NULL);
    CFIndex idxb = CFArrayBSearchValues(rangeSet->array, CFRangeMake(0, count), (void*)b, uintptrComparator, NULL);
    if(idxa >= count || idxb == 0)
        return [HFRangeSet withRange:range];
    
    // Alright, the trivial responses are past. We'll need to build a new set.
    // Given the fencepost representation of sets, we can efficiently produce an
    // inverted set by just copying the fenceposts between 'a' and 'b', and then
    // maybe including 'a' and 'b'.
    
    HFRangeSet *newSet = [[[HFRangeSet alloc] init] autorelease];

    // newSet must contain all the fenceposts strictly between 'a' and 'b'
    CFIndex copyloc = (uintptr_t)CFArrayGetValueAtIndex(rangeSet->array, idxa) == a ? idxa+1 : idxa;
    CFIndex copylen = idxb - copyloc;
    
    // Include 'a' if it's needed to invert the parity of the copy.
    if(copyloc % 2 == 0) CFArrayAppendValue(newSet->array, &a);
    
    CFArrayAppendArray(newSet->array, rangeSet->array, CFRangeMake(copyloc, copylen));
    
    // Include 'b' if it's needed to close off the set.
    if(CFArrayGetCount(newSet->array) % 2 == 1)
        CFArrayAppendValue(newSet->array, &b);

    assert(CFArrayGetCount(newSet->array) % 2 == 0);
    return newSet;
}


- (void)addRange:(HFRange)range {
    if(range.length == 0) return;
    HFRangeSetAddRange(array, ll2p(range.location), ll2p(HFMaxRange(range)));
}
- (void)removeRange:(HFRange)range {
    if(range.length == 0) return;
    HFRangeSetRemoveRange(array, ll2p(range.location), ll2p(HFMaxRange(range)));
}
- (void)toggleRange:(HFRange)range {
    if(range.length == 0) return;
    HFRangeSetToggleRange(array, ll2p(range.location), ll2p(HFMaxRange(range)));
}

- (void)clipToRange:(HFRange)range {
    if(range.length <= 0) {
        CFArrayRemoveAllValues(array);
        return;
    }
    uintptr_t a = ll2p(range.location);
    uintptr_t b = ll2p(HFMaxRange(range));
    CFIndex count = CFArrayGetCount(array);
    CFIndex idxa = CFArrayBSearchValues(array, CFRangeMake(0, count), (void*)a, uintptrComparator, NULL);
    CFIndex idxb = CFArrayBSearchValues(array, CFRangeMake(0, count), (void*)b, uintptrComparator, NULL);
    if(idxa >= count || idxb == 0) {
        CFArrayRemoveAllValues(array);
        return;
    }
    
    // Keep only fenceposts strictly between 'a' and 'b', and then possibly
    // add 'a' or 'b' as fenceposts.
    CFIndex keeploc = (uintptr_t)CFArrayGetValueAtIndex(array, idxa) == a ? idxa+1 : idxa;
    CFIndex keeplen = idxb - keeploc;
    
    // Include 'a' if it's needed to keep the parity straight.
    if(keeploc % 2 == 1) {
        keeploc--; keeplen++;
        CFArraySetValueAtIndex(array, keeploc, (void*)a);
    }
    
    if(keeploc > 0)
        CFArrayReplaceValues(array, CFRangeMake(0, keeploc), NULL, 0);
    if(keeploc+keeplen < count)
        CFArrayReplaceValues(array, CFRangeMake(0, keeplen), NULL, 0);
    
    // Include 'b' if it's needed to keep the length even.
    if(keeplen % 2 == 1) {
        CFArrayAppendValue(array, (void*)b);
    }
    
    assert(CFArrayGetCount(array) % 2 == 0);
}


- (void)addRangeSet:(HFRangeSet *)rangeSet {
    CFArrayRef a = rangeSet->array;
    CFIndex c = CFArrayGetCount(a);
    for(CFIndex i2 = 0; i2 < c; i2 += 2) {
        HFRangeSetAddRange(array, (uintptr_t)CFArrayGetValueAtIndex(a, i2), (uintptr_t)CFArrayGetValueAtIndex(a, i2+1));
    }
}
- (void)removeRangeSet:(HFRangeSet *)rangeSet {
    CFArrayRef a = rangeSet->array;
    CFIndex c = CFArrayGetCount(a);
    for(CFIndex i2 = 0; i2 < c; i2 += 2) {
        HFRangeSetRemoveRange(array, (uintptr_t)CFArrayGetValueAtIndex(a, i2), (uintptr_t)CFArrayGetValueAtIndex(a, i2+1));
    }
}
- (void)toggleRangeSet:(HFRangeSet *)rangeSet {
    CFArrayRef a = rangeSet->array;
    CFIndex c = CFArrayGetCount(a);
    for(CFIndex i2 = 0; i2 < c; i2 += 2) {
        HFRangeSetToggleRange(array, (uintptr_t)CFArrayGetValueAtIndex(a, i2), (uintptr_t)CFArrayGetValueAtIndex(a, i2+1));
    }
}

- (void)clipToRangeSet:(HFRangeSet *)rangeSet {
    HFRange span = [rangeSet spanningRange];
    [self clipToRange:span];
    [self removeRangeSet:[HFRangeSet complementOfRangeSet:rangeSet inRange:span]];
}

- (BOOL)isEqualToRangeSet:(HFRangeSet *)rangeSet {
    // Because our arrays are fully normalized, this just checks for array equality.
    CFArrayRef a = rangeSet->array;
    CFIndex c = CFArrayGetCount(a);
    if(c != CFArrayGetCount(array))
        return NO;
    
    // Optimization: For long arrays, check the last few first,
    // since appending to ranges is probably a common usage pattern.
    const CFIndex opt_end = 10;
    if(c > 2*opt_end) {
        for(CFIndex i = c - 2*opt_end; i < c; i++) {
            if(CFArrayGetValueAtIndex(a, i) != CFArrayGetValueAtIndex(array, i))
                return NO;
        }
        c -= 2*opt_end;
    }
    
    for(CFIndex i = 0; i < c; i++) {
        if(CFArrayGetValueAtIndex(a, i) != CFArrayGetValueAtIndex(array, i))
            return NO;
    }
    
    return YES;
}

- (BOOL)isEmpty {
    return CFArrayGetCount(array) == 0;
}

- (BOOL)containsAllRange:(HFRange)range {
    if(range.length == 0) return YES;
    return HFRangeSetContainsAllRange(array, ll2p(range.location), ll2p(HFMaxRange(range)));
}

- (BOOL)overlapsAnyRange:(HFRange)range {
    if(range.length == 0) return NO;
    return HFRangeSetOverlapsAnyRange(array, ll2p(range.location), ll2p(HFMaxRange(range)));
}

- (BOOL)containsAllRangeSet:(HFRangeSet *)rangeSet {
    CFArrayRef a = rangeSet->array;
    CFIndex c = CFArrayGetCount(a);
    
    // Optimization: check if containment is possible.
    if(!HFRangeIsSubrangeOfRange([rangeSet spanningRange], [self spanningRange])) {
        return NO;
    }
    
    for(CFIndex i2 = 0; i2 < c; i2 += 2) {
        uintptr_t x = (uintptr_t)CFArrayGetValueAtIndex(a, i2);
        uintptr_t y = (uintptr_t)CFArrayGetValueAtIndex(a, i2+1);
        if(!HFRangeSetContainsAllRange(array, x, y)) return NO;
    }
    return YES;
}

- (BOOL)overlapsAnyRangeSet:(HFRangeSet *)rangeSet {
    CFArrayRef a = rangeSet->array;
    CFIndex c = CFArrayGetCount(a);

    // Optimization: check if overlap is possible.
    if(!HFIntersectsRange([rangeSet spanningRange], [self spanningRange])) {
        return NO;
    }

    for(CFIndex i2 = 0; i2 < c; i2 += 2) {
        uintptr_t x = (uintptr_t)CFArrayGetValueAtIndex(a, i2);
        uintptr_t y = (uintptr_t)CFArrayGetValueAtIndex(a, i2+1);
        if(!HFRangeSetOverlapsAnyRange(array, x, y)) return YES;
    }
    return NO;
}


- (HFRange)spanningRange {
    CFIndex count = CFArrayGetCount(array);
    if(count == 0) return HFZeroRange;
    
    uintptr_t a = (uintptr_t)CFArrayGetValueAtIndex(array, 0);
    uintptr_t b = (uintptr_t)CFArrayGetValueAtIndex(array, count-2) + (uintptr_t)CFArrayGetValueAtIndex(array, count-1);
    
    return HFRangeMake(a, b-a);
}

- (void)assertIntegrity {
    CFIndex count = CFArrayGetCount(array);
    HFASSERT(count % 2 == 0);
    if(count == 0) return;
    
    uintptr_t prev = (uintptr_t)CFArrayGetValueAtIndex(array, 0);
    for(CFIndex i = 1; i < count; i++) {
        uintptr_t val = (uintptr_t)CFArrayGetValueAtIndex(array, i);
        HFASSERT(val > prev);
        prev = val;
    }
}

- (BOOL)isEqual:(id)object {
    if(![object isKindOfClass:[HFRangeSet class]])
        return false;
    return [self isEqualToRangeSet:object];
}

- (NSUInteger)hash {
    CFIndex count = CFArrayGetCount(array);
    NSUInteger x = 0;
    for(CFIndex i2 = 0; i2 < count; i2 += 2) {
        uintptr_t a = (uintptr_t)CFArrayGetValueAtIndex(array, i2);
        uintptr_t b = (uintptr_t)CFArrayGetValueAtIndex(array, i2+1);
#if 6364136223846793005 < NSUIntegerMax
        x = (6364136223846793005 * (uint64_t)x + a);
#else
        x = (NSUInteger)(1103515245 * (uint64_t)x + a);
#endif
        x ^= (NSUInteger)b;
    }
    return x;
}

- (id)copyWithZone:(NSZone *)zone {
    HFRangeSet *newSet = [[HFRangeSet allocWithZone:zone] init];
    CFRelease(newSet->array);
    newSet->array = (CFMutableArrayRef)[[NSMutableArray allocWithZone:zone] initWithArray:(NSArray*)array copyItems:NO];
    return newSet;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    NSUInteger count = CFArrayGetCount(array);
    NEW_ARRAY(uint64_t, values, count);
    
    // Fill array with 64-bit, little endian bytes.
    if(sizeof(const void *) == sizeof(uint64_t)) {
        // Hooray, we can just use CFArrayGetValues
        CFArrayGetValues(array, CFRangeMake(0, count), (const void **)&values);
#if __LITTLE_ENDIAN__
#else
        // Boo, we have to swap everything.
        for(NSUInteger i = 0; i < count; i++) {
            values[i] = CFSwapInt64HostToLittle(values[i]);
        }
#endif
    } else {
        // Boo, we have to iterate through the array.
        NSUInteger i = 0;
        FOREACH(id, val, (NSArray*)array) {
            values[i++] = CFSwapInt64HostToLittle((uint64_t)(const void *)val);
        }
    }
    [aCoder encodeBytes:values length:count * sizeof(*values)];
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    if(!(self = [super init])) return nil;
    
    NSUInteger count;
    uint64_t *values = [aDecoder decodeBytesWithReturnedLength:&count];
    array = CFArrayCreateMutable(kCFAllocatorDefault, count+1, NULL);
    
    for(NSUInteger i = 0; i < count; i++) {
        uint64_t x = CFSwapInt64LittleToHost(values[i]);
        if(x > UINTPTR_MAX)
            goto fail;
        CFArrayAppendValue(array, (const void *)(uintptr_t)x);
    }
    if(CFArrayGetCount(array)%2 != 0)
        goto fail;
    return self;
    
fail:
    CFRelease(array);
    [super release];
    return nil;
}

+ (BOOL)supportsSecureCoding {
    return YES;
}

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state objects:(id *)stackbuf count:(NSUInteger)len {
    NSUInteger base = state->state;
    NSUInteger length = CFArrayGetCount(array)/2;
    NSUInteger i = 0;
    
    while(i < len && base + i < length) {
        uintptr_t a = (uintptr_t)CFArrayGetValueAtIndex(array, 2*i);
        uintptr_t b = (uintptr_t)CFArrayGetValueAtIndex(array, 2*i+1);
        stackbuf[i] = [HFRangeWrapper withRange:HFRangeMake(a, b-a)];
    }
    
    state->state = base + i;
    state->itemsPtr = stackbuf;
    state->mutationsPtr = &state->extra[0]; // Use simple mutation checking.
    state->extra[0] = length;
    
    return i;
}

@end


BOOL HFStringEncodingIsSupersetOfASCII(NSStringEncoding encoding) {
    switch (CFStringConvertNSStringEncodingToEncoding(encoding)) {
	case kCFStringEncodingMacRoman: return YES;
	case kCFStringEncodingWindowsLatin1: return YES;
	case kCFStringEncodingISOLatin1: return YES;
	case kCFStringEncodingNextStepLatin: return YES;
	case kCFStringEncodingASCII: return YES;
	case kCFStringEncodingUnicode: return NO;
	case kCFStringEncodingUTF8: return YES;
	case kCFStringEncodingNonLossyASCII: return NO;
//	case kCFStringEncodingUTF16: return NO;
	case kCFStringEncodingUTF16BE: return NO;
	case kCFStringEncodingUTF16LE: return NO;
	case kCFStringEncodingUTF32: return NO;
	case kCFStringEncodingUTF32BE: return NO;
	case kCFStringEncodingUTF32LE: return NO;
	case kCFStringEncodingMacJapanese: return NO;
	case kCFStringEncodingMacChineseTrad: return YES;
	case kCFStringEncodingMacKorean: return YES;
	case kCFStringEncodingMacArabic: return NO;
	case kCFStringEncodingMacHebrew: return NO;
	case kCFStringEncodingMacGreek: return YES;
	case kCFStringEncodingMacCyrillic: return YES;
	case kCFStringEncodingMacDevanagari: return YES;
	case kCFStringEncodingMacGurmukhi: return YES;
	case kCFStringEncodingMacGujarati: return YES;
	case kCFStringEncodingMacOriya: return YES;
	case kCFStringEncodingMacBengali: return YES;
	case kCFStringEncodingMacTamil: return YES;
	case kCFStringEncodingMacTelugu: return YES;
	case kCFStringEncodingMacKannada: return YES;
	case kCFStringEncodingMacMalayalam: return YES;
	case kCFStringEncodingMacSinhalese: return YES;
	case kCFStringEncodingMacBurmese: return YES;
	case kCFStringEncodingMacKhmer: return YES;
	case kCFStringEncodingMacThai: return YES;
	case kCFStringEncodingMacLaotian: return YES;
	case kCFStringEncodingMacGeorgian: return YES;
	case kCFStringEncodingMacArmenian: return YES;
	case kCFStringEncodingMacChineseSimp: return YES;
	case kCFStringEncodingMacTibetan: return YES;
	case kCFStringEncodingMacMongolian: return YES;
	case kCFStringEncodingMacEthiopic: return YES;
	case kCFStringEncodingMacCentralEurRoman: return YES;
	case kCFStringEncodingMacVietnamese: return YES;
	case kCFStringEncodingMacExtArabic: return YES;
	case kCFStringEncodingMacSymbol: return NO;
	case kCFStringEncodingMacDingbats: return NO;
	case kCFStringEncodingMacTurkish: return YES;
	case kCFStringEncodingMacCroatian: return YES;
	case kCFStringEncodingMacIcelandic: return YES;
	case kCFStringEncodingMacRomanian: return YES;
	case kCFStringEncodingMacCeltic: return YES;
	case kCFStringEncodingMacGaelic: return YES;
	case kCFStringEncodingMacFarsi: return YES;
	case kCFStringEncodingMacUkrainian: return NO;
	case kCFStringEncodingMacInuit: return YES;
	case kCFStringEncodingMacVT100: return YES;
	case kCFStringEncodingMacHFS: return YES;
	case kCFStringEncodingISOLatin2: return YES;
	case kCFStringEncodingISOLatin3: return YES;
	case kCFStringEncodingISOLatin4: return YES;
	case kCFStringEncodingISOLatinCyrillic: return YES;
	case kCFStringEncodingISOLatinArabic: return NO;
	case kCFStringEncodingISOLatinGreek: return YES;
	case kCFStringEncodingISOLatinHebrew: return YES;
	case kCFStringEncodingISOLatin5: return YES;
	case kCFStringEncodingISOLatin6: return YES;
	case kCFStringEncodingISOLatinThai: return YES;
	case kCFStringEncodingISOLatin7: return YES;
	case kCFStringEncodingISOLatin8: return YES;
	case kCFStringEncodingISOLatin9: return YES;
	case kCFStringEncodingISOLatin10: return YES;
	case kCFStringEncodingDOSLatinUS: return YES;
	case kCFStringEncodingDOSGreek: return YES;
	case kCFStringEncodingDOSBalticRim: return YES;
	case kCFStringEncodingDOSLatin1: return YES;
	case kCFStringEncodingDOSGreek1: return YES;
	case kCFStringEncodingDOSLatin2: return YES;
	case kCFStringEncodingDOSCyrillic: return YES;
	case kCFStringEncodingDOSTurkish: return YES;
	case kCFStringEncodingDOSPortuguese: return YES;
	case kCFStringEncodingDOSIcelandic: return YES;
	case kCFStringEncodingDOSHebrew: return YES;
	case kCFStringEncodingDOSCanadianFrench: return YES;
	case kCFStringEncodingDOSArabic: return YES;
	case kCFStringEncodingDOSNordic: return YES;
	case kCFStringEncodingDOSRussian: return YES;
	case kCFStringEncodingDOSGreek2: return YES;
	case kCFStringEncodingDOSThai: return YES;
	case kCFStringEncodingDOSJapanese: return YES;
	case kCFStringEncodingDOSChineseSimplif: return YES;
	case kCFStringEncodingDOSKorean: return YES;
	case kCFStringEncodingDOSChineseTrad: return YES;
	case kCFStringEncodingWindowsLatin2: return YES;
	case kCFStringEncodingWindowsCyrillic: return YES;
	case kCFStringEncodingWindowsGreek: return YES;
	case kCFStringEncodingWindowsLatin5: return YES;
	case kCFStringEncodingWindowsHebrew: return YES;
	case kCFStringEncodingWindowsArabic: return YES;
	case kCFStringEncodingWindowsBalticRim: return YES;
	case kCFStringEncodingWindowsVietnamese: return YES;
	case kCFStringEncodingWindowsKoreanJohab: return YES;
	case kCFStringEncodingANSEL: return NO;
	case kCFStringEncodingJIS_X0201_76: return NO;
	case kCFStringEncodingJIS_X0208_83: return NO;
	case kCFStringEncodingJIS_X0208_90: return NO;
	case kCFStringEncodingJIS_X0212_90: return NO;
	case kCFStringEncodingJIS_C6226_78: return NO;
	case 0x0628/*kCFStringEncodingShiftJIS_X0213*/: return NO;
	case kCFStringEncodingShiftJIS_X0213_MenKuTen: return NO;
	case kCFStringEncodingGB_2312_80: return NO;
	case kCFStringEncodingGBK_95: return NO;
	case kCFStringEncodingGB_18030_2000: return NO;
	case kCFStringEncodingKSC_5601_87: return NO;
	case kCFStringEncodingKSC_5601_92_Johab: return NO;
	case kCFStringEncodingCNS_11643_92_P1: return NO;
	case kCFStringEncodingCNS_11643_92_P2: return NO;
	case kCFStringEncodingCNS_11643_92_P3: return NO;
	case kCFStringEncodingISO_2022_JP: return NO;
	case kCFStringEncodingISO_2022_JP_2: return NO;
	case kCFStringEncodingISO_2022_JP_1: return NO;
	case kCFStringEncodingISO_2022_JP_3: return NO;
	case kCFStringEncodingISO_2022_CN: return NO;
	case kCFStringEncodingISO_2022_CN_EXT: return NO;
	case kCFStringEncodingISO_2022_KR: return NO;
	case kCFStringEncodingEUC_JP: return YES;
	case kCFStringEncodingEUC_CN: return YES;
	case kCFStringEncodingEUC_TW: return YES;
	case kCFStringEncodingEUC_KR: return YES;
	case kCFStringEncodingShiftJIS: return NO;
	case kCFStringEncodingKOI8_R: return YES;
	case kCFStringEncodingBig5: return YES;
	case kCFStringEncodingMacRomanLatin1: return YES;
	case kCFStringEncodingHZ_GB_2312: return NO;
	case kCFStringEncodingBig5_HKSCS_1999: return YES;
	case kCFStringEncodingVISCII: return YES; // though not quite
	case kCFStringEncodingKOI8_U: return YES;
	case kCFStringEncodingBig5_E: return YES;
	case kCFStringEncodingNextStepJapanese: return YES;
	case kCFStringEncodingEBCDIC_US: return NO;
	case kCFStringEncodingEBCDIC_CP037: return NO;
        default:
            NSLog(@"Unknown string encoding %lu in %s", (unsigned long)encoding, __FUNCTION__);
            return NO;
    }
}

uint8_t HFStringEncodingCharacterLength(NSStringEncoding encoding) {
    switch (CFStringConvertNSStringEncodingToEncoding(encoding)) {
	case kCFStringEncodingMacRoman: return 1;
	case kCFStringEncodingWindowsLatin1: return 1;
	case kCFStringEncodingISOLatin1: return 1;
	case kCFStringEncodingNextStepLatin: return 1;
	case kCFStringEncodingASCII: return 1;
	case kCFStringEncodingUnicode: return 2;
	case kCFStringEncodingUTF8: return 1;
	case kCFStringEncodingNonLossyASCII: return 1;
            //	case kCFStringEncodingUTF16: return 2;
	case kCFStringEncodingUTF16BE: return 2;
	case kCFStringEncodingUTF16LE: return 2;
	case kCFStringEncodingUTF32: return 4;
	case kCFStringEncodingUTF32BE: return 4;
	case kCFStringEncodingUTF32LE: return 4;
	case kCFStringEncodingMacJapanese: return 1;
	case kCFStringEncodingMacChineseTrad: return 1; // ??
	case kCFStringEncodingMacKorean: return 1;
	case kCFStringEncodingMacArabic: return 1;
	case kCFStringEncodingMacHebrew: return 1;
	case kCFStringEncodingMacGreek: return 1;
	case kCFStringEncodingMacCyrillic: return 1;
	case kCFStringEncodingMacDevanagari: return 1;
	case kCFStringEncodingMacGurmukhi: return 1;
	case kCFStringEncodingMacGujarati: return 1;
	case kCFStringEncodingMacOriya: return 1;
	case kCFStringEncodingMacBengali: return 1;
	case kCFStringEncodingMacTamil: return 1;
	case kCFStringEncodingMacTelugu: return 1;
	case kCFStringEncodingMacKannada: return 1;
	case kCFStringEncodingMacMalayalam: return 1;
	case kCFStringEncodingMacSinhalese: return 1;
	case kCFStringEncodingMacBurmese: return 1;
	case kCFStringEncodingMacKhmer: return 1;
	case kCFStringEncodingMacThai: return 1;
	case kCFStringEncodingMacLaotian: return 1;
	case kCFStringEncodingMacGeorgian: return 1;
	case kCFStringEncodingMacArmenian: return 1;
	case kCFStringEncodingMacChineseSimp: return 1;
	case kCFStringEncodingMacTibetan: return 1;
	case kCFStringEncodingMacMongolian: return 1;
	case kCFStringEncodingMacEthiopic: return 1;
	case kCFStringEncodingMacCentralEurRoman: return 1;
	case kCFStringEncodingMacVietnamese: return 1;
	case kCFStringEncodingMacExtArabic: return 1;
	case kCFStringEncodingMacSymbol: return 1;
	case kCFStringEncodingMacDingbats: return 1;
	case kCFStringEncodingMacTurkish: return 1;
	case kCFStringEncodingMacCroatian: return 1;
	case kCFStringEncodingMacIcelandic: return 1;
	case kCFStringEncodingMacRomanian: return 1;
	case kCFStringEncodingMacCeltic: return 1;
	case kCFStringEncodingMacGaelic: return 1;
	case kCFStringEncodingMacFarsi: return 1;
	case kCFStringEncodingMacUkrainian: return 1;
	case kCFStringEncodingMacInuit: return 1;
	case kCFStringEncodingMacVT100: return 1;
	case kCFStringEncodingMacHFS: return 1;
	case kCFStringEncodingISOLatin2: return 1;
	case kCFStringEncodingISOLatin3: return 1;
	case kCFStringEncodingISOLatin4: return 1;
	case kCFStringEncodingISOLatinCyrillic: return 1;
	case kCFStringEncodingISOLatinArabic: return 1;
	case kCFStringEncodingISOLatinGreek: return 1;
	case kCFStringEncodingISOLatinHebrew: return 1;
	case kCFStringEncodingISOLatin5: return 1;
	case kCFStringEncodingISOLatin6: return 1;
	case kCFStringEncodingISOLatinThai: return 1;
	case kCFStringEncodingISOLatin7: return 1;
	case kCFStringEncodingISOLatin8: return 1;
	case kCFStringEncodingISOLatin9: return 1;
	case kCFStringEncodingISOLatin10: return 1;
	case kCFStringEncodingDOSLatinUS: return 1;
	case kCFStringEncodingDOSGreek: return 1;
	case kCFStringEncodingDOSBalticRim: return 1;
	case kCFStringEncodingDOSLatin1: return 1;
	case kCFStringEncodingDOSGreek1: return 1;
	case kCFStringEncodingDOSLatin2: return 1;
	case kCFStringEncodingDOSCyrillic: return 1;
	case kCFStringEncodingDOSTurkish: return 1;
	case kCFStringEncodingDOSPortuguese: return 1;
	case kCFStringEncodingDOSIcelandic: return 1;
	case kCFStringEncodingDOSHebrew: return 1;
	case kCFStringEncodingDOSCanadianFrench: return 1;
	case kCFStringEncodingDOSArabic: return 1;
	case kCFStringEncodingDOSNordic: return 1;
	case kCFStringEncodingDOSRussian: return 1;
	case kCFStringEncodingDOSGreek2: return 1;
	case kCFStringEncodingDOSThai: return 1;
	case kCFStringEncodingDOSJapanese: return 1;
	case kCFStringEncodingDOSChineseSimplif: return 1;
	case kCFStringEncodingDOSKorean: return 1;
	case kCFStringEncodingDOSChineseTrad: return 1;
	case kCFStringEncodingWindowsLatin2: return 1;
	case kCFStringEncodingWindowsCyrillic: return 1;
	case kCFStringEncodingWindowsGreek: return 1;
	case kCFStringEncodingWindowsLatin5: return 1;
	case kCFStringEncodingWindowsHebrew: return 1;
	case kCFStringEncodingWindowsArabic: return 1;
	case kCFStringEncodingWindowsBalticRim: return 1;
	case kCFStringEncodingWindowsVietnamese: return 1;
	case kCFStringEncodingWindowsKoreanJohab: return 1;
	case kCFStringEncodingANSEL: return 1;
	case kCFStringEncodingJIS_X0201_76: return 1;
	case kCFStringEncodingJIS_X0208_83: return 1;
	case kCFStringEncodingJIS_X0208_90: return 1;
	case kCFStringEncodingJIS_X0212_90: return 1;
	case kCFStringEncodingJIS_C6226_78: return 1;
	case 0x0628/*kCFStringEncodingShiftJIS_X0213*/: return 1;
	case kCFStringEncodingShiftJIS_X0213_MenKuTen: return 1;
	case kCFStringEncodingGB_2312_80: return 1;
	case kCFStringEncodingGBK_95: return 1;
	case kCFStringEncodingGB_18030_2000: return 1;
	case kCFStringEncodingKSC_5601_87: return 1;
	case kCFStringEncodingKSC_5601_92_Johab: return 1;
	case kCFStringEncodingCNS_11643_92_P1: return 1;
	case kCFStringEncodingCNS_11643_92_P2: return 1;
	case kCFStringEncodingCNS_11643_92_P3: return 1;
	case kCFStringEncodingISO_2022_JP: return 1;
	case kCFStringEncodingISO_2022_JP_2: return 1;
	case kCFStringEncodingISO_2022_JP_1: return 1;
	case kCFStringEncodingISO_2022_JP_3: return 1;
	case kCFStringEncodingISO_2022_CN: return 1;
	case kCFStringEncodingISO_2022_CN_EXT: return 1;
	case kCFStringEncodingISO_2022_KR: return 1;
	case kCFStringEncodingEUC_JP: return 1;
	case kCFStringEncodingEUC_CN: return 1;
	case kCFStringEncodingEUC_TW: return 1;
	case kCFStringEncodingEUC_KR: return 1;
	case kCFStringEncodingShiftJIS: return 1;
	case kCFStringEncodingKOI8_R: return 1;
	case kCFStringEncodingBig5: return 2; //yay, a 2
	case kCFStringEncodingMacRomanLatin1: return 1;
	case kCFStringEncodingHZ_GB_2312: return 2;
	case kCFStringEncodingBig5_HKSCS_1999: return 1;
	case kCFStringEncodingVISCII: return 1;
	case kCFStringEncodingKOI8_U: return 1;
	case kCFStringEncodingBig5_E: return 2;
	case kCFStringEncodingNextStepJapanese: return YES; // ??
	case kCFStringEncodingEBCDIC_US: return 1; //lol
	case kCFStringEncodingEBCDIC_CP037: return 1;
	case kCFStringEncodingUTF7: return 1;
	case kCFStringEncodingUTF7_IMAP : return 1;
        default:
            NSLog(@"Unknown string encoding %lx in %s", (long)encoding, __FUNCTION__);
            return 1;
    }    
}

/* Converts a hexadecimal digit into a corresponding 4 bit unsigned int; returns -1 on failure.  The ... is a gcc extension. */
static NSInteger char2hex(unichar c) {
    switch (c) {
        case '0' ... '9': return c - '0';
        case 'a' ... 'f': return c - 'a' + 10;
        case 'A' ... 'F': return c - 'A' + 10;
        default: return -1;
    }
}

static unsigned char hex2char(NSUInteger c) {
    HFASSERT(c < 16);
    return "0123456789ABCDEF"[c];
}

NSData *HFDataFromHexString(NSString *string, BOOL* isMissingLastNybble) {
    REQUIRE_NOT_NULL(string);
    NSUInteger stringIndex=0, resultIndex=0, max=[string length];
    NSMutableData* result = [NSMutableData dataWithLength:(max + 1)/2];
    unsigned char* bytes = [result mutableBytes];
    
    NSUInteger numNybbles = 0;
    unsigned char byteValue = 0;
    
    for (stringIndex = 0; stringIndex < max; stringIndex++) {
        NSInteger val = char2hex([string characterAtIndex:stringIndex]);
        if (val < 0) continue;
        numNybbles++;
        byteValue = byteValue * 16 + (unsigned char)val;
        if (! (numNybbles % 2)) {
            bytes[resultIndex++] = byteValue;
            byteValue = 0;
        }
    }
    
    if (isMissingLastNybble) *isMissingLastNybble = (numNybbles % 2);
    
    //final nibble
    if (numNybbles % 2) {
        bytes[resultIndex++] = byteValue;
    }
    
    [result setLength:resultIndex];
    return result;    
}

NSString *HFHexStringFromData(NSData *data) {
    REQUIRE_NOT_NULL(data);
    NSUInteger dataLength = [data length];
    NSUInteger stringLength = HFProductInt(dataLength, 2);
    const unsigned char *bytes = [data bytes];
    unsigned char *charBuffer = check_malloc(stringLength);
    NSUInteger charIndex = 0, byteIndex;
    for (byteIndex = 0; byteIndex < dataLength; byteIndex++) {
        unsigned char byte = bytes[byteIndex];
        charBuffer[charIndex++] = hex2char(byte >> 4);
        charBuffer[charIndex++] = hex2char(byte & 0xF);
    }
    return [[[NSString alloc] initWithBytesNoCopy:charBuffer length:stringLength encoding:NSASCIIStringEncoding freeWhenDone:YES] autorelease];
}

void HFSetFDShouldCache(int fd, BOOL shouldCache) {
    int result = fcntl(fd, F_NOCACHE, !shouldCache);
    if (result == -1) {
        int err = errno;
        NSLog(@"fcntl(%d, F_NOCACHE, %d) returned error %d: %s", fd, !shouldCache, err, strerror(err));
    }
}

NSString *HFDescribeByteCount(unsigned long long count) {
    return HFDescribeByteCountWithPrefixAndSuffix(NULL, count, NULL);
}

/* A big_num represents a number in some base.  Here it is value = big * base + little. */
typedef struct big_num {
    unsigned int big; 
    unsigned long long little;
} big_num;

static inline big_num divide_bignum_by_2(big_num a, unsigned long long base) {
    //value = a.big * base + a.little;
    big_num result;
    result.big = a.big / 2;
    unsigned int shiftedRemainder = (unsigned int)(a.little & 1);
    result.little = a.little / 2;
    if (a.big & 1) {
        //need to add base/2 to result.little.  We know that won't overflow because result.little is already a.little / 2
        result.little += base / 2;
        
        // If we shift off a bit for base/2, and we also shifted off a bit for a.little/2, then we have a carry bit we need to add
        if ((base & 1) && shiftedRemainder) {
            /* Is there a chance that adding 1 will overflow?  We know base is odd (base & 1), so consider an example of base = 9.  Then the largest that result.little could be is (9 - 1)/2 + base/2 = 8.  We could add 1 and get back to base, but we can never exceed base, so we cannot overflow an unsigned long long. */
            result.little += 1;
            HFASSERT(result.little <= base);
            if (result.little == base) {
                result.big++;
                result.little = 0;
            }
        }
    }
    HFASSERT(result.little < base);
    return result;
}

static inline big_num add_big_nums(big_num a, big_num b, unsigned long long base) {
    /* Perform the addition result += left.  The addition is:
      result.big = a.big + b.big + (a.little + b.little) / base
      result.little = (a.little + b.little) % base
      
      a.little + b.little may overflow, so we have to take some care in how we calculate them.
      Since both a.little and b.little are less than base, we know that if we overflow, we can subtract base from it to underflow and still get the same remainder.
    */
    unsigned long long remainder = a.little + b.little;
    unsigned int dividend = 0;
    // remainder < a.little detects overflow, and remainder >= base detects the case where we did not overflow but are larger than base
    if (remainder < a.little || remainder >= base) {
        remainder -= base;
        dividend++;
    }
    HFASSERT(remainder < base);
    
    big_num result = {a.big + b.big + dividend, remainder};
    return result;
}


/* Returns the first digit after the decimal point for a / b, rounded off, without overflow.  This may return 10, indicating that the digit is 0 and we should carry. */
static unsigned int computeRemainderPrincipalDigit(unsigned long long a, unsigned long long base) {
    struct big_num result = {0, 0}, left = {(unsigned)(a / base), a % base}, right = {(unsigned)(100 / base), 100 % base};
    while (right.big > 0 || right.little > 0) {
        /* Determine the least significant bit of right, which is right.big * base + right.little */
        unsigned int bigTermParity = (base & 1) && (right.big & 1);
        unsigned int littleTermParity = (unsigned)(right.little & 1);
        if (bigTermParity != littleTermParity) result = add_big_nums(result, left, base);

        right = divide_bignum_by_2(right, base);
        left = add_big_nums(left, left, base);
    }

    //result.big now contains 100 * a / base
    unsigned int principalTwoDigits = (unsigned int)(result.big % 100);
    unsigned int principalDigit = (principalTwoDigits / 10) + ((principalTwoDigits % 10) >= 5);
    return principalDigit;
}

NSString *HFDescribeByteCountWithPrefixAndSuffix(const char *stringPrefix, unsigned long long count, const char *stringSuffix) {
    if (! stringPrefix) stringPrefix = "";
    if (! stringSuffix) stringSuffix = "";

    if (count == 0) return [NSString stringWithFormat:@"%s0 bytes%s", stringPrefix, stringSuffix];
                            
    const struct {
        unsigned long long size;
        const char *suffix;
    } suffixes[] = {
        {1ULL<<0,   "byte"},
        {1ULL<<10,  "byte"},
        {1ULL<<20,  "kilobyte"},
        {1ULL<<30,  "megabyte"},
        {1ULL<<40,  "gigabyte"},
        {1ULL<<50,  "terabyte"},
        {1ULL<<60,  "petabyte"},
        {ULLONG_MAX, "exabyte"}
    };
    const unsigned numSuffixes = sizeof suffixes / sizeof *suffixes;
    //HFASSERT((sizeof sizes / sizeof *sizes) == (sizeof suffixes / sizeof *suffixes));
    unsigned i;
    unsigned long long base;
    for (i=0; i < numSuffixes; i++) {
        if (count < suffixes[i].size || suffixes[i].size == ULLONG_MAX) break;
    }
    
    if (i >= numSuffixes) return [NSString stringWithFormat:@"%san unbelievable number of bytes%s", stringPrefix, stringSuffix];
    base = suffixes[i-1].size;
    
    unsigned long long dividend = count / base;
    unsigned int remainderPrincipalDigit = computeRemainderPrincipalDigit(count % base, base);
    HFASSERT(remainderPrincipalDigit <= 10);
    if (remainderPrincipalDigit == 10) {
        /* Carry */
        dividend++;
        remainderPrincipalDigit = 0;
    }
        
    BOOL needsPlural = (dividend != 1 || remainderPrincipalDigit > 0);
    
    char remainderBuff[64];
    if (remainderPrincipalDigit > 0) snprintf(remainderBuff, sizeof remainderBuff, ".%u", remainderPrincipalDigit);
    else remainderBuff[0] = 0;
    
    char* resultPointer = NULL;
    int numChars = asprintf(&resultPointer, "%s%llu%s %s%s%s", stringPrefix, dividend, remainderBuff, suffixes[i].suffix, needsPlural ? "s" : "", stringSuffix);
    if (numChars < 0) return NULL;
    return [[[NSString alloc] initWithBytesNoCopy:resultPointer length:numChars encoding:NSASCIIStringEncoding freeWhenDone:YES] autorelease];
}

static CGFloat interpolateShadow(CGFloat val) {
    //A value of 1 means we are at the rightmost, and should return our max value.  By adjusting the scale, we control how quickly the shadow drops off.
    CGFloat scale = 1.4;
    return (CGFloat)(expm1(val * scale) / expm1(scale));
}

void HFDrawShadow(CGContextRef ctx, NSRect rect, CGFloat shadowSize, NSRectEdge rectEdge, BOOL drawActive, NSRect clip) {
    NSRect remainingRect, unused;
    NSDivideRect(rect, &remainingRect, &unused, shadowSize, rectEdge);
    
    CGFloat maxAlpha = (drawActive ? .25 : .10);

    for (CGFloat i=0; i < shadowSize; i++) {
        NSRect shadowLine;
        NSDivideRect(remainingRect, &shadowLine, &remainingRect, 1, rectEdge);
        
        NSRect clippedLine = NSIntersectionRect(shadowLine, clip);
        if (! NSIsEmptyRect(clippedLine)) {   
            CGFloat gray = 0.;
            CGFloat alpha = maxAlpha * interpolateShadow((shadowSize - i) / shadowSize);
            CGContextSetGrayFillColor(ctx, gray, alpha);
            CGContextFillRect(ctx, NSRectToCGRect(clippedLine));
        }
    }

}

void HFRegisterViewForWindowAppearanceChanges(NSView *self, SEL notificationSEL, BOOL appToo) {
    NSWindow *window = [self window];
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    if (window) {
        [center addObserver:self selector:notificationSEL name:NSWindowDidBecomeKeyNotification object:window];
        [center addObserver:self selector:notificationSEL name:NSWindowDidResignKeyNotification object:window];
    }
    if (appToo) {
        [center addObserver:self selector:notificationSEL name:NSApplicationDidBecomeActiveNotification object:nil];
        [center addObserver:self selector:notificationSEL name:NSApplicationDidResignActiveNotification object:nil];        
    }
}

void HFUnregisterViewForWindowAppearanceChanges(NSView *self, BOOL appToo) {
    NSWindow *window = [self window];
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    if (window) {
        [center removeObserver:self name:NSWindowDidBecomeKeyNotification object:window];
        [center removeObserver:self name:NSWindowDidResignKeyNotification object:window];        
    }
    if (appToo) {
        [center removeObserver:self name:NSApplicationDidBecomeActiveNotification object:nil];
        [center removeObserver:self name:NSApplicationDidResignActiveNotification object:nil];
    }    
}

#if USE_CHUD
void HFStartTiming(const char *name) {
    static BOOL inited;
    if (! inited) {
        inited = YES;
        chudInitialize();
        chudSetErrorLogFile(stderr);
        chudAcquireRemoteAccess();
    }
    chudStartRemotePerfMonitor(name);
    
}

void HFStopTiming(void) {
    chudStopRemotePerfMonitor();
}
#else
void HFStartTiming(const char *name) { USE(name); }
void HFStopTiming(void) { }
#endif
