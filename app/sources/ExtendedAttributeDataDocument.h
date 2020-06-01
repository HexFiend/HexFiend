//
//  ExtendedAttributeDataDocument.h
//  HexFiend_2
//
//  Created by Kevin Wojniak on 2/3/19.
//  Copyright © 2019 ridiculous_fish. All rights reserved.
//

#import "BaseDataDocument.h"

@interface ExtendedAttributeDataDocument : BaseDataDocument

- (instancetype)initWithAttributeName:(NSString *)name forURL:(NSURL *)url;

@end
