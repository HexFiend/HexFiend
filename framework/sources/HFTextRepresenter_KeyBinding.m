//
//  HFTextRepresenter_KeyBinding.m
//  HexFiend_2
//
//  Created by Peter Ammon on 11/24/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <HexFiend/HFTextRepresenter.h>
#import <HexFiend/HFRepresenterTextView.h>
#import <HexFiend/HFController.h>

#define FORWARD(x) - (void)x : sender { USE(sender); id rep = [self representer]; if ([rep respondsToSelector:_cmd]) { [rep x : sender]; } else if ([self nextResponder]) [[self nextResponder] doCommandBySelector:_cmd]; else NSBeep(); }

@implementation HFRepresenterTextView (HFKeyBinding)

FORWARD(moveForward)
FORWARD(moveRight)
FORWARD(moveBackward)
FORWARD(moveLeft)
FORWARD(moveUp)
FORWARD(moveDown)
FORWARD(moveWordForward)
FORWARD(moveWordBackward)
FORWARD(moveToBeginningOfLine)
FORWARD(moveToEndOfLine)
FORWARD(moveToBeginningOfParagraph)
FORWARD(moveToEndOfParagraph)
FORWARD(moveToEndOfDocument)
FORWARD(moveToBeginningOfDocument)
FORWARD(pageDown)
FORWARD(pageUp)
FORWARD(centerSelectionInVisibleArea)
FORWARD(moveBackwardAndModifySelection)
FORWARD(moveForwardAndModifySelection)
FORWARD(moveWordForwardAndModifySelection)
FORWARD(moveWordBackwardAndModifySelection)
FORWARD(moveUpAndModifySelection)
FORWARD(moveDownAndModifySelection)
FORWARD(moveWordRight)
FORWARD(moveWordLeft)
FORWARD(moveRightAndModifySelection)
FORWARD(moveLeftAndModifySelection)
FORWARD(moveWordRightAndModifySelection)
FORWARD(moveWordLeftAndModifySelection)
FORWARD(scrollPageUp)
FORWARD(scrollPageDown)
FORWARD(scrollLineUp)
FORWARD(scrollLineDown)
FORWARD(transpose)
FORWARD(transposeWords)
FORWARD(selectAll)
FORWARD(selectParagraph)
FORWARD(selectLine)
FORWARD(selectWord)
FORWARD(indent)
FORWARD(insertTab)
FORWARD(insertBacktab)
FORWARD(insertNewline)
FORWARD(insertParagraphSeparator)
FORWARD(insertNewlineIgnoringFieldEditor)
FORWARD(insertTabIgnoringFieldEditor)
FORWARD(insertLineBreak)
FORWARD(insertContainerBreak)
FORWARD(changeCaseOfLetter)
FORWARD(uppercaseWord)
FORWARD(lowercaseWord)
FORWARD(capitalizeWord)
FORWARD(deleteForward)
FORWARD(deleteBackward)
FORWARD(deleteBackwardByDecomposingPreviousCharacter)
FORWARD(deleteWordForward)
FORWARD(deleteWordBackward)
FORWARD(deleteToBeginningOfLine)
FORWARD(deleteToEndOfLine)
FORWARD(deleteToBeginningOfParagraph)
FORWARD(deleteToEndOfParagraph)
FORWARD(yank)
FORWARD(complete)
FORWARD(setMark)
FORWARD(deleteToMark)
FORWARD(selectToMark)
FORWARD(swapWithMark)
FORWARD(cancelOperation)

@end

#undef FORWARD()
#define FORWARD(x) - (void)x : sender { USE(sender); UNIMPLEMENTED_VOID(); }

@implementation HFTextRepresenter (HFKeyBinding)

- (void)moveRight:unused { USE(unused); [[self controller] moveDirection:HFControllerDirectionRight andModifySelection:NO]; }
- (void)moveLeft:unused { USE(unused); [[self controller] moveDirection:HFControllerDirectionLeft andModifySelection:NO]; }
- (void)moveUp:unused { USE(unused); [[self controller] moveDirection:HFControllerDirectionUp andModifySelection:NO]; }
- (void)moveDown:unused { USE(unused); [[self controller] moveDirection:HFControllerDirectionDown andModifySelection:NO]; }	
- (void)moveRightAndModifySelection:unused { USE(unused); [[self controller] moveDirection:HFControllerDirectionRight andModifySelection:YES]; }
- (void)moveLeftAndModifySelection:unused { USE(unused); [[self controller] moveDirection:HFControllerDirectionLeft andModifySelection:YES]; }
- (void)moveUpAndModifySelection:unused { USE(unused); [[self controller] moveDirection:HFControllerDirectionUp andModifySelection:YES]; }
- (void)moveDownAndModifySelection:unused { USE(unused); [[self controller] moveDirection:HFControllerDirectionDown andModifySelection:YES]; }

- (void)moveForward:unused { USE(unused); [self moveRight:unused]; }
- (void)moveBackward:unused { USE(unused); [self moveLeft:unused]; }

- (void)moveWordForward:unused { USE(unused); [self moveForward:unused]; }
- (void)moveWordBackward:unused { USE(unused); [self moveBackward:unused]; }

- (void)moveBackwardAndModifySelection:unused { USE(unused); [self moveLeftAndModifySelection:unused]; }
- (void)moveForwardAndModifySelection:unused { USE(unused); [self moveRightAndModifySelection:unused]; }
- (void)moveWordForwardAndModifySelection:unused { USE(unused); [self moveForwardAndModifySelection:unused]; }
- (void)moveWordBackwardAndModifySelection:unused { USE(unused); [self moveBackwardAndModifySelection:unused]; }
- (void)moveWordRight:unused { USE(unused); [self moveRight:unused]; }
- (void)moveWordLeft:unused { USE(unused); [self moveLeft:unused];  }
- (void)moveWordRightAndModifySelection:unused { USE(unused); [self moveRightAndModifySelection:unused]; }
- (void)moveWordLeftAndModifySelection:unused { USE(unused); [self moveLeftAndModifySelection:unused]; }

- (void)deleteBackward:unused { USE(unused); [[self controller] deleteDirection:HFControllerDirectionLeft]; }
- (void)deleteForward:unused { USE(unused); [[self controller] deleteDirection:HFControllerDirectionRight]; }
- (void)deleteWordForward:unused { USE(unused); [self deleteForward:unused]; }
- (void)deleteWordBackward:unused { USE(unused); [self deleteBackward:unused]; }

- (void)delete:unused { USE(unused); [self deleteForward:unused]; }

	//todo: implement these

- (void)deleteToBeginningOfLine:(id)sender { }
- (void)deleteToEndOfLine:(id)sender { }
- (void)deleteToBeginningOfParagraph:(id)sender { }
- (void)deleteToEndOfParagraph:(id)sender { }

- (void)moveToBeginningOfLine:unused { USE(unused); [[self controller] bulkMove:HFControllerMovementLine inDirection:HFControllerDirectionLeft andModifySelection:NO]; }
- (void)moveToEndOfLine:unused { USE(unused); [[self controller] bulkMove:HFControllerMovementLine inDirection:HFControllerDirectionRight andModifySelection:NO]; }
- (void)moveToBeginningOfDocument:unused { USE(unused); [[self controller] bulkMove:HFControllerMovementDocument inDirection:HFControllerDirectionLeft andModifySelection:NO]; }
- (void)moveToEndOfDocument:unused { USE(unused); [[self controller] bulkMove:HFControllerMovementDocument inDirection:HFControllerDirectionRight andModifySelection:NO]; }

- (void)moveToBeginningOfLineAndModifySelection:unused { USE(unused); [[self controller] bulkMove:HFControllerMovementLine inDirection:HFControllerDirectionLeft andModifySelection:YES]; }
- (void)moveToEndOfLineAndModifySelection:unused { USE(unused); [[self controller] bulkMove:HFControllerMovementLine inDirection:HFControllerDirectionRight andModifySelection:YES]; }
- (void)moveToBeginningOfDocumentAndModifySelection:unused { USE(unused); [[self controller] bulkMove:HFControllerMovementDocument inDirection:HFControllerDirectionLeft andModifySelection:YES]; }
- (void)moveToEndOfDocumentAndModifySelection:unused { USE(unused); [[self controller] bulkMove:HFControllerMovementDocument inDirection:HFControllerDirectionRight andModifySelection:YES]; }

- (void)moveToBeginningOfParagraph:unused { USE(unused); [self moveToBeginningOfLine:unused]; }
- (void)moveToEndOfParagraph:unused { USE(unused); [self moveToBeginningOfLine:unused]; }
- (void)moveToBeginningOfParagraphAndModifySelection:unused { USE(unused); [self moveToBeginningOfLineAndModifySelection:unused]; }
- (void)moveToEndOfParagraphAndModifySelection:unused { USE(unused); [self moveToEndOfLineAndModifySelection:unused]; }

- (void)scrollPageDown:unused { USE(unused); [[self controller] scrollByLines:(int)[[self controller] visibleLines]]; }
- (void)scrollPageUp:unused { USE(unused); [[self controller] scrollByLines: -(int)[[self controller] visibleLines]]; }
- (void)pageDown:unused { USE(unused); [self scrollPageDown:unused]; }
- (void)pageUp:unused { USE(unused); [self scrollPageUp:unused]; }
- (void)centerSelectionInVisibleArea:unused { USE(unused); }



FORWARD(scrollLineUp)
FORWARD(scrollLineDown)
FORWARD(transpose)
FORWARD(transposeWords)
FORWARD(selectAll)
FORWARD(selectParagraph)
FORWARD(selectLine)
FORWARD(selectWord)
FORWARD(indent)
FORWARD(insertTab)
FORWARD(insertBacktab)
FORWARD(insertNewline)
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
FORWARD(cancelOperation)

@end

