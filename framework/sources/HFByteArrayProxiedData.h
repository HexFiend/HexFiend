//
//  HFByteArrayDataProxy.h
//  HexFiend_2
//
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <HexFiend/HFFrameworkPrefix.h>

NS_ASSUME_NONNULL_BEGIN

@class HFByteArray;

/*! @class HFByteArrayDataProxy
    @brief A class to proxy an HFByteArray as an NSData.
    
    HFByteArrayDataProxy exposes an HFByteArray as an immutable NSData.  Because this requires serializing the byte array into a memory buffer, this can range between inefficient and impossible (if the byte array is large).  This class should normally not be used.
*/
@interface HFByteArrayProxiedData : NSData {
    NSData *serializedData;
    HFByteArray *byteArray;
    NSUInteger length;
}

- (instancetype)initWithByteArray:(HFByteArray *)array;

@end

NS_ASSUME_NONNULL_END
