//
//  HFStatusBarRepresenter.h
//  HexFiend_2
//
//  Created by Peter Ammon on 12/16/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <HexFiend/HFRepresenter.h>

enum {
    HFStatusModeDecimal,
    HFStatusModeHexadecimal,
    HFStatusModeApproximate,
    HFSTATUSMODECOUNT
};

@interface HFStatusBarRepresenter : HFRepresenter {
    NSUInteger statusMode;
}

- (NSUInteger)statusMode;
- (void)setStatusMode:(NSUInteger)mode;

@end
