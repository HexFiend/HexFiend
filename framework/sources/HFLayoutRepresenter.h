//
//  HFLayoutRepresenter.h
//  HexFiend_2
//
//  Created by Peter Ammon on 12/10/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <HexFiend/HFRepresenter.h>

/* An HFLayoutRepresenter is a representer responsible for arranging the views of HFRepresenters */
@interface HFLayoutRepresenter : HFRepresenter {
    NSMutableArray *representers;
    BOOL maximizesBytesPerLine;
    
}

/* Methods for dealing with representers */
- (NSArray *)representers;
- (void)addRepresenter:(HFRepresenter *)representer;
- (void)removeRepresenter:(HFRepresenter *)representer;

/* Returns the rect in which to layout the representers.  Defaults to [[self view] bounds] */
- (NSRect)boundsRectForLayout;

/* You may override this to return any view within which to layout the representers views. */
- (NSView *)createView;

/* Determines whether HFLayoutRepresenter will attempt to maximize the bytes per line so as to consume as much as possible of the bounds rect. */
- (void)setMaximizesBytesPerLine:(BOOL)val;
- (BOOL)maximizesBytesPerLine;

/* Returns the smallest width that produces the same layout (and, if maximizes bytesPerLine, the same bytes per line) as the proposed width. */
- (CGFloat)minimumWidthForLayoutInProposedWidth:(CGFloat)proposedWidth;

@end
