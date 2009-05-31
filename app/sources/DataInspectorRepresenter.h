#import <Cocoa/Cocoa.h>
#import <HexFiend/HexFiend.h>

//notification posted when our DataInspector's height changes.  Has a single key "height" which is the new height for the scroll view
extern NSString * const DataInspectorDidChangeSize;

@interface DataInspectorRepresenter : HFRepresenter {
    IBOutlet NSView *outletView; //used only for loading the nib
    IBOutlet NSTableView *table;
    NSMutableArray *inspectors;
}

- (void)loadDefaultInspectors;

- (IBAction)addRow:(id)sender;
- (IBAction)removeRow:(id)sender;

@end

@interface DataInspectorScrollView : NSScrollView
@end

@interface DataInspectorPlusMinusButtonCell : NSButtonCell
@end

@interface DataInspectorTableView : NSTableView
@end
