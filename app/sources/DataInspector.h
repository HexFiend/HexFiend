//
//  DataInspector.h
//  HexFiend_2
//
//  Copyright © 2019 ridiculous_fish. All rights reserved.
//

#import <HexFiend/HexFiend.h>

/* The largest number of bytes that any inspector type can edit */
#define MAX_EDITABLE_BYTE_COUNT 128

// Inspector types
// Needs to match menu order in DataInspectorView.xib
enum InspectorType_t {
    eInspectorTypeSignedInteger,
    eInspectorTypeUnsignedInteger,
    eInspectorTypeFloatingPoint,
    eInspectorTypeUTF8Text,
    eInspectorTypeSLEB128,
    eInspectorTypeULEB128,
    eInspectorTypeBinary,
    
    // Total number of inspector types.
    eInspectorTypeCount
};

// Needs to match menu order in DataInspectorView.xib
enum Endianness_t {
    eEndianLittle, // (Endianness_t)0 is the default endianness.
    eEndianBig,
    
    // Total number of endiannesses.
    eEndianCount,
    
    eNativeEndianness = eEndianLittle
};

enum NumberBase_t {
    eNumberBaseDecimal,
    eNumberBaseHexadecimal,
};

/* A class representing a single row of the data inspector */
@interface DataInspector : NSObject<NSCoding> {
    enum InspectorType_t inspectorType;
    enum Endianness_t endianness;
    enum NumberBase_t numberBase;
}

/* A data inspector that is different from the given inspectors, if possible. */
+ (DataInspector*)dataInspectorSupplementing:(NSArray*)inspectors;

@property (nonatomic) enum InspectorType_t type;
@property (nonatomic) enum Endianness_t endianness;
@property (nonatomic) enum NumberBase_t numberBase;

- (NSAttributedString *)valueForController:(HFController *)controller ranges:(NSArray*)ranges isError:(BOOL *)outIsError;
- (NSAttributedString *)valueForData:(NSData *)data isError:(BOOL *)outIsError;
- (NSAttributedString *)valueForBytes:(const unsigned char *)bytes length:(NSUInteger)length isError:(BOOL *)outIsError;

/* Returns YES if we can replace the given number of bytes with this string value */
- (BOOL)acceptStringValue:(NSString *)value replacingByteCount:(NSUInteger)count intoData:(unsigned char *)outData;

/* Get and set a property list representation, for persisting to user defaults */
@property (nonatomic, strong) id propertyListRepresentation;

@end
