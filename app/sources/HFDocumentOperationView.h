//
//  HFDocumentOperationView.h
//  HexFiend_2
//
//  Created by Peter Ammon on 2/26/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface HFDocumentOperationView : NSView {
    NSMutableDictionary *views;
    NSMutableDictionary *viewNamesToFrames;
    NSString *nibName;
    NSSize defaultSize;
    BOOL awokenFromNib;
}

+ viewWithNibNamed:(NSString *)name;
- viewNamed:(NSString *)name;
- (CGFloat)defaultHeight;

@end
