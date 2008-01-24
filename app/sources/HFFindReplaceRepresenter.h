//
//  HFFindReplaceRepresenter.h
//  HexFiend_2
//
//  Created by Peter Ammon on 1/24/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <HexFiend/HFRepresenter.h>

@class HFFindReplaceBackgroundView, HFController;

@interface HFFindReplaceRepresenter : HFRepresenter {
    IBOutlet HFFindReplaceBackgroundView *backgroundView; 
    IBOutlet NSSegmentedControl *navigateView;
    
    HFController *findReplaceController;
    HFLayoutRepresenter *findReplaceLayout;
}

- (IBAction)findNextOrPrevious:sender;

@end
