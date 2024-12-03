#import "ViewController.h"

#import <AVKit/AVKit.h>

/// Content URL.
static NSString *const kBackupContentUrl =
    @"http://devimages.apple.com/iphone/samples/bipbop/bipbopall.m3u8";

@interface ViewController ()
/// Play button.
@property(nonatomic, weak) IBOutlet UIButton *playButton;

@property(nonatomic, weak) IBOutlet UIView *videoView;
/// Video player.
@property(nonatomic, strong) AVPlayer *videoPlayer;
@end

@implementation ViewController

- (void)viewDidLoad {
  [super viewDidLoad];
  self.view.backgroundColor = [UIColor blackColor];

  // Load AVPlayer with the path to your content.
  NSURL *contentURL = [NSURL URLWithString:kBackupContentUrl];
  self.videoPlayer = [AVPlayer playerWithURL:contentURL];

  // Create a player layer for the player.
  AVPlayerLayer *playerLayer = [AVPlayerLayer playerLayerWithPlayer:self.videoPlayer];

  // Size, position, and display the AVPlayer.
  playerLayer.frame = self.videoView.layer.bounds;
  [self.videoView.layer addSublayer:playerLayer];
}

- (IBAction)onPlayButtonTouch:(id)sender {
  [self.videoPlayer play];
  self.playButton.hidden = YES;
}

@end
