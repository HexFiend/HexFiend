//
//  HFPrivilegedHelperConnection.h
//  HexFiend_2
//
//  Created by Peter Ammon on 7/31/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface HFPrivilegedHelperConnection : NSObject {
}

+ (HFPrivilegedHelperConnection *)sharedConnection;
- (void)launchAndConnect;

@end
