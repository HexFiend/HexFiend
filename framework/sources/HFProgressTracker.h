//
//  HFProgressTracker.h
//  HexFiend_2
//
//  Created by peter on 2/12/08.
//  Copyright 2008 ridiculous_fish. All rights reserved.
//

#import <HexFiend/HFFrameworkPrefix.h>

NS_ASSUME_NONNULL_BEGIN

/*!
@class HFProgressTracker
@brief A class that helps handle progress indication and cancellation for long running threaded operations.

  HFProgressTracker is a class that helps handle progress indication and cancellation for long running threaded operations, while imposing minimal overhead.  Operations such as Find/Replace or Save take an HFProgressTracker to provide cancellation and progress reporting.

  The thread is expected to write directly into the public currentProgress field (perhaps with atomic functions) as it makes progress.  Once beginTrackingProgress is called, the HFProgressTracker will poll currentProgress until endTrackingProgress is called.

  The thread is also expected to read directly from cancelRequested, which is set by the requestCancel method.  If requestCancel is set, it should end the operation.
  
  Lastly, the thread is expected to call noteFinished: when it is done, either through cancellation or completing normally.
  
  On the client side, you can set a delegate. progressTracker: didChangeProgressTo: is called on your delegate at regular intervals in the main thread, as the progress changes.  Likewise, progressTrackerDidFinish: is called on the main thread after noteFinished: is called.
  
  There is also a progressIndicator property, which if set to an NSProgressIndicator will cause it to be updated regularly.
    
*/

@interface HFProgressTracker : NSObject {
    @public
    volatile unsigned long long currentProgress;
    volatile int cancelRequested;
    @private
    unsigned long long maxProgress;
#if !TARGET_OS_IPHONE
    NSProgressIndicator *progressIndicator;
#endif
    NSTimer *progressTimer;
    double lastSetValue;
    id delegate;
}

/*!
  HFProgressTracker determines the progress as an unsigned long long, but passes the progress to the delegate as a double, which is computed as the current progress divided by the max progress.
*/
@property (nonatomic) unsigned long long maxProgress;

/*!
  The userInfo property is a convenience to allow passing information to the thread.  The property is not thread safe - the expectation is that the main thread will set it before the operation starts, and the background thread will read it once after the operation starts.
*/
@property (nonatomic, copy) NSDictionary *userInfo;

#if !TARGET_OS_IPHONE
/*!
  The progressIndicator property allows an NSProgressIndicator to be associated with the HFProgressTracker.  The progress indicator should have values in the range 0 to 1, and it will be updated with the fraction currentProgress / maxProgress.
*/
@property (nullable, nonatomic, strong) NSProgressIndicator *progressIndicator;
#endif

/*!
  Called to indicate you want to begin tracking the progress, which means that the progress indicator will be updated, and the delegate callbacks may fire.
*/
- (void)beginTrackingProgress;

/*!
  Called to indicate you want to end tracking progress.  The progress indicator will no longer be updated.
*/
- (void)endTrackingProgress;

/*!
  noteFinished: should be called by the thread when it is done.  It is safe to call this from the background thread.
*/
- (void)noteFinished:(id)sender;

/*!
  requestCancel: may be called to mark the cancelRequested variable.  The thread should poll this variable to determine if it needs to cancel.
*/
- (void)requestCancel:(id)sender;

/*!
  Set and get the delegate, which may implement the optional methods below.
*/
@property (nullable, nonatomic, weak) id delegate;

@end


/*!
@protocol HFProgressTrackerDelegate
@brief The delegate methods for the HFProgressTracker class.

The HFProgressTrackerDelegate methods are called on the the HFProgressTracker's delegate.  These are always called on the main thread.
*/
@protocol HFProgressTrackerDelegate <NSObject>

/*!
  Once beginTrackingProgress is called, this is called on the delegate at regular intervals to report on the new progress.
*/
- (void)progressTracker:(HFProgressTracker *)tracker didChangeProgressTo:(double)fraction;

/*!
  Once the thread has called noteFinished:, this is called on the delegate in the main thread to report that the background thread is done.
*/
- (void)progressTrackerDidFinish:(HFProgressTracker *)tracker;

@end

NS_ASSUME_NONNULL_END
