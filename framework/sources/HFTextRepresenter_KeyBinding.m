//
//  HFTextRepresenter_KeyBinding.m
//  HexFiend_2
//
//  Copyright 2007 ridiculous_fish. All rights reserved.
//

#import <HexFiend/HFTextRepresenter.h>
#import <HexFiend/HFRepresenterTextView.h>
#import <HexFiend/HFController.h>

#define FORWARD(x) - (void)x : sender { USE(sender); UNIMPLEMENTED_VOID(); }

@implementation HFTextRepresenter (HFKeyBinding)

- (void)moveRight:unused { USE(unused); [[self controller] moveInDirection:HFControllerDirectionRight withGranularity:HFControllerMovementByte andModifySelection:NO]; }
- (void)moveLeft:unused { USE(unused); [[self controller] moveInDirection:HFControllerDirectionLeft withGranularity:HFControllerMovementByte andModifySelection:NO]; }
- (void)moveUp:unused { USE(unused); [[self controller] moveInDirection:HFControllerDirectionLeft withGranularity:HFControllerMovementLine andModifySelection:NO]; }
- (void)moveDown:unused { USE(unused); [[self controller] moveInDirection:HFControllerDirectionRight withGranularity:HFControllerMovementLine andModifySelection:NO]; }	
- (void)moveWordRight:unused { USE(unused); [[self controller] moveInDirection:HFControllerDirectionRight withGranularity:HFControllerMovementColumn andModifySelection:NO]; }
- (void)moveWordLeft:unused { USE(unused); [[self controller] moveInDirection:HFControllerDirectionLeft withGranularity:HFControllerMovementColumn andModifySelection:NO]; }

- (void)moveRightAndModifySelection:unused { USE(unused); [[self controller] moveInDirection:HFControllerDirectionRight withGranularity:HFControllerMovementByte andModifySelection:YES]; }
- (void)moveLeftAndModifySelection:unused { USE(unused); [[self controller] moveInDirection:HFControllerDirectionLeft withGranularity:HFControllerMovementByte andModifySelection:YES]; }
- (void)moveUpAndModifySelection:unused { USE(unused); [[self controller] moveInDirection:HFControllerDirectionLeft withGranularity:HFControllerMovementLine andModifySelection:YES]; }
- (void)moveDownAndModifySelection:unused { USE(unused); [[self controller] moveInDirection:HFControllerDirectionRight withGranularity:HFControllerMovementLine andModifySelection:YES]; }
- (void)moveWordRightAndModifySelection:unused { USE(unused); [[self controller] moveInDirection:HFControllerDirectionRight withGranularity:HFControllerMovementColumn andModifySelection:YES]; }
- (void)moveWordLeftAndModifySelection:unused { USE(unused); [[self controller] moveInDirection:HFControllerDirectionLeft withGranularity:HFControllerMovementColumn andModifySelection:YES]; }

- (void)moveForward:unused { USE(unused); [self moveRight:unused]; }
- (void)moveBackward:unused { USE(unused); [self moveLeft:unused]; }

- (void)moveWordForward:unused { USE(unused); [self moveWordRight:unused]; }
- (void)moveWordBackward:unused { USE(unused); [self moveWordLeft:unused]; }
- (void)moveForwardAndModifySelection:unused { USE(unused); [self moveRightAndModifySelection:unused]; }
- (void)moveBackwardAndModifySelection:unused { USE(unused); [self moveLeftAndModifySelection:unused]; }
- (void)moveWordForwardAndModifySelection:unused { USE(unused); [self moveForwardAndModifySelection:unused]; }
- (void)moveWordBackwardAndModifySelection:unused { USE(unused); [self moveBackwardAndModifySelection:unused]; }

- (void)deleteBackward:unused { USE(unused); [[self controller] deleteDirection:HFControllerDirectionLeft]; }
- (void)deleteForward:unused { USE(unused); [[self controller] deleteDirection:HFControllerDirectionRight]; }
- (void)deleteWordForward:unused { USE(unused); [self deleteForward:unused]; }
- (void)deleteWordBackward:unused { USE(unused); [self deleteBackward:unused]; }

- (void)delete:unused { USE(unused); [self deleteForward:unused]; }

	//todo: implement these

- (void)deleteToBeginningOfLine:(id)sender { USE(sender); }
- (void)deleteToEndOfLine:(id)sender { USE(sender); }
- (void)deleteToBeginningOfParagraph:(id)sender { USE(sender); }
- (void)deleteToEndOfParagraph:(id)sender { USE(sender); }

- (void)moveToBeginningOfLine:unused { USE(unused); [[self controller] moveToLineBoundaryInDirection:HFControllerDirectionLeft andModifySelection:NO]; }
- (void)moveToEndOfLine:unused { USE(unused); [[self controller] moveToLineBoundaryInDirection:HFControllerDirectionRight andModifySelection:NO]; }
- (void)moveToBeginningOfDocument:unused { USE(unused); [[self controller] moveInDirection:HFControllerDirectionLeft withGranularity:HFControllerMovementDocument andModifySelection:NO]; }
- (void)moveToEndOfDocument:unused { USE(unused); [[self controller] moveInDirection:HFControllerDirectionRight withGranularity:HFControllerMovementDocument andModifySelection:NO]; }

- (void)moveToBeginningOfLineAndModifySelection:unused { USE(unused); [[self controller] moveToLineBoundaryInDirection:HFControllerDirectionLeft andModifySelection:YES]; }
- (void)moveToEndOfLineAndModifySelection:unused { USE(unused); [[self controller] moveToLineBoundaryInDirection:HFControllerDirectionRight andModifySelection:YES]; }
- (void)moveToBeginningOfDocumentAndModifySelection:unused { USE(unused); [[self controller] moveInDirection:HFControllerDirectionLeft withGranularity:HFControllerMovementDocument andModifySelection:YES]; }
- (void)moveToEndOfDocumentAndModifySelection:unused { USE(unused); [[self controller] moveInDirection:HFControllerDirectionRight withGranularity:HFControllerMovementDocument andModifySelection:YES]; }

- (void)moveToBeginningOfParagraph:unused { USE(unused); [self moveToBeginningOfLine:unused]; }
- (void)moveToEndOfParagraph:unused { USE(unused); [self moveToEndOfLine:unused]; }
- (void)moveToBeginningOfParagraphAndModifySelection:unused { USE(unused); [self moveToBeginningOfLineAndModifySelection:unused]; }
- (void)moveToEndOfParagraphAndModifySelection:unused { USE(unused); [self moveToEndOfLineAndModifySelection:unused]; }

- (void)scrollPageDown:unused { USE(unused); [[self controller] scrollByLines:[[self controller] displayedLineRange].length]; }
- (void)scrollPageUp:unused { USE(unused); [[self controller] scrollByLines: -  [[self controller] displayedLineRange].length]; }
- (void)pageDown:unused { USE(unused); [self scrollPageDown:unused]; }
- (void)pageUp:unused { USE(unused); [self scrollPageUp:unused]; }

- (void)centerSelectionInVisibleArea:unused {
    USE(unused);
    HFController *controller = [self controller];
    NSArray *selection = [controller selectedContentsRanges];
    unsigned long long min = ULLONG_MAX, max = 0;
    HFASSERT([selection count] >= 1);
    FOREACH(HFRangeWrapper *, wrapper, selection) {
	HFRange range = [wrapper HFRange];
	min = MIN(min, range.location);
	max = MAX(max, HFMaxRange(range));
    }
    HFASSERT(max >= min);
    [controller maximizeVisibilityOfContentsRange:HFRangeMake(min, max - min)];
}

- (void)insertTab:unused {
    USE(unused);
    [[[self view] window] selectNextKeyView:nil];
}

- (void)insertBacktab:unused {
    USE(unused);
    [[[self view] window] selectPreviousKeyView:nil];
}

FORWARD(scrollLineUp)
FORWARD(scrollLineDown)
FORWARD(transpose)
FORWARD(transposeWords)

FORWARD(selectParagraph)
FORWARD(selectLine)
FORWARD(selectWord)
FORWARD(indent)
//FORWARD(insertNewline)
FORWARD(insertParagraphSeparator)
FORWARD(insertNewlineIgnoringFieldEditor)
FORWARD(insertTabIgnoringFieldEditor)
FORWARD(insertLineBreak)
FORWARD(insertContainerBreak)
FORWARD(changeCaseOfLetter)
FORWARD(uppercaseWord)
FORWARD(lowercaseWord)
FORWARD(capitalizeWord)
FORWARD(deleteBackwardByDecomposingPreviousCharacter)
FORWARD(yank)
FORWARD(complete)
FORWARD(setMark)
FORWARD(deleteToMark)
FORWARD(selectToMark)
FORWARD(swapWithMark)
//FORWARD(cancelOperation)

@end

