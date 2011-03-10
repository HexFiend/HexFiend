#import "BaseDataDocument.h"


@interface BaseDataDocument (AppDebugging)

- (void)installDebuggingMenuItems:(NSMenu *)menu;

@end

@interface GenericPrompt : NSWindowController {
    IBOutlet NSTextField *promptField, *valueField;
    IBOutlet NSWindow *window;
    
    NSString *promptText;
}

@end
