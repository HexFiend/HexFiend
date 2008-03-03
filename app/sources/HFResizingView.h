#import <Cocoa/Cocoa.h>

/* A view that correctly handles subview resizing even as it shrinks to zero size, as long as the views are present in awakeFromNib */

@interface HFResizingView : NSView {
    __strong CFMutableDictionaryRef viewsToInitialFrames;
    NSSize defaultSize;
    BOOL hasAwokenFromNib;
}

@end
