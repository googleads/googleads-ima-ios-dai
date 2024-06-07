#import <UIKit/UIKit.h>

#import "Video.h"

@class IMAAdsLoader;
@class VideoViewController;

@protocol VideoViewControllerDelegate

/// Notified when the current progress for the provided video should be saved. Used for bookmarking.
- (void)videoViewController:(VideoViewController *)viewController
         didReportSavedTime:(NSTimeInterval)savedTime
                   forVideo:(Video *)video;
@end

@interface VideoViewController : UIViewController

// UI Outlets
@property(nonatomic, weak) IBOutlet UILabel *topLabel;
@property(nonatomic, weak) IBOutlet UIView *videoView;
@property(nonatomic, weak) IBOutlet UIToolbar *videoControls;
@property(nonatomic, weak) IBOutlet UIButton *playHeadButton;
@property(nonatomic, weak) IBOutlet UITextField *playHeadTimeText;
@property(nonatomic, weak) IBOutlet UITextField *durationTimeText;
@property(nonatomic, weak) IBOutlet UISlider *progressBar;
@property(nonatomic, weak) IBOutlet UIButton *pictureInPictureButton;

/// Text view used for log messages.
@property(nonatomic, weak) IBOutlet UITextView *consoleView;

/// Video object to play.
@property(nonatomic, strong) Video *video;

// AdsLoader
@property(nonatomic, strong) IMAAdsLoader *adsLoader;

/// Delegate for above VideoViewControllerDelegate.
@property(nonatomic, weak) id<VideoViewControllerDelegate> delegate;

/// Tracks whether or not we have requested a stream locally.
@property(nonatomic, assign) BOOL localStreamRequested;

/// Returns the content time for the currently playing stream.
- (NSTimeInterval)getContentTime;

/// Updates the play button control for the provided playing status.
- (void)updatePlayHeadState:(BOOL)isPlaying;

/// Updates the player controls with the provided duration.
- (void)updatePlayHeadDurationWithTime:(CMTime)duration;

/// Updates the player controls with the provided current time and duration.
- (void)updatePlayHeadWithTime:(CMTime)time duration:(CMTime)duration;

@end
