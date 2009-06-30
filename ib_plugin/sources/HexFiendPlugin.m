#import "HexFiendPlugin.h"
#import <HexFiend/HFTextView.h>

@implementation HexFiendPlugin

- (NSArray *)libraryNibNames {
    return [NSArray arrayWithObject:@"HexFiendPluginLibrary"];
}

- (NSArray *)requiredFrameworks {
    return [NSArray arrayWithObject:[NSBundle bundleForClass:[HFTextView class]]];
}

@end
