//
//  HFCustomEncoding.h
//  HexFiend_Framework
//
//  Created by Kevin Wojniak on 6/16/18.
//  Copyright © 2018 ridiculous_fish. All rights reserved.
//

#import <HexFiend/HexFiend.h>

@interface HFCustomEncoding : HFStringEncoding <NSCoding>

- (nullable instancetype)initWithPath:(nonnull NSString *)path;

@end
