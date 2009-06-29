#import "HexFiendPlugin.h"
#import <HexFiend/HFTextView.h>

@implementation HexFiendPlugin

- (NSArray *)libraryNibNames {
    return [NSArray arrayWithObject:@"HexFiendPluginLibrary"];
}

- (NSArray *)requiredFrameworks {
    NSLog(@"%@", [NSBundle bundleForClass:[HFTextView class]]);
    return [NSArray arrayWithObject:[NSBundle bundleForClass:[HFTextView class]]];
}

@end
