//
//  HFASCIITextRepresenter.h
//  HexFiend_2
//
//  Created by Peter Ammon on 11/11/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <HexFiend/HFTextRepresenter.h>


@interface HFStringEncodingTextRepresenter : HFTextRepresenter {

}

- (NSStringEncoding)encoding;
- (void)setEncoding:(NSStringEncoding)encoding;

@end
