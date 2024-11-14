#import "ViewController.h"

#import <AVFoundation/AVFoundation.h>

// [START import_ima_sdk]
@import GoogleInteractiveMediaAds;

/// Fallback URL in case something goes wrong in loading the stream. This stream is not used, unless
/// an error has occurred.
static NSString *const kBackupContentUrl =
    @"http://devimages.apple.com/iphone/samples/bipbop/bipbopall.m3u8";

/// Live stream asset key.
static NSString *const kAssetKey = @"c-rArva4ShKVIAkNfy6HUQ";
/// VOD content source ID.
static NSString *const kContentSourceID = @"2548831";
/// VOD video ID.
static NSString *const kVideoID = @"tears-of-steel";

@interface ViewController () <IMAAdsLoaderDelegate, IMAStreamManagerDelegate>
/// Entry point for the SDK. Used to make ad requests.
@property(nonatomic, strong) IMAAdsLoader *adsLoader;
/// The container where the SDK renders each ad's user interface elements.
@property(nonatomic, strong) IMAAdDisplayContainer *adDisplayContainer;
/// An implementation of the `IMA Video Display` protocol. Used to give the SDK access to your video
/// player.
@property(nonatomic, strong) IMAAVPlayerVideoDisplay *imaVideoDisplay;
/// The main point of interaction with the SDK. Created by the SDK as the result of a successful ad
/// request.
@property(nonatomic, strong) IMAStreamManager *streamManager;
// [END import_ima_sdk]

/// Content video player.
@property(nonatomic, strong) AVPlayer *contentPlayer;

// UI
/// Play button.
@property(nonatomic, weak) IBOutlet UIButton *playButton;
/// UIView in which we will render our AVPlayer for content.
@property(nonatomic, weak) IBOutlet UIView *videoView;

@end

@implementation ViewController

- (void)viewDidLoad {
  [super viewDidLoad];

  self.playButton.layer.zPosition = MAXFLOAT; 

  // Load AVPlayer with path to our content.
  NSURL *contentURL = [NSURL URLWithString:kBackupContentUrl];
  self.contentPlayer = [AVPlayer playerWithURL:contentURL];

  // Create a player layer for the player.
  AVPlayerLayer *playerLayer = [AVPlayerLayer playerLayerWithPlayer:self.contentPlayer];

  // Size, position, and display the AVPlayer.
  playerLayer.frame = self.videoView.layer.bounds;
  [self.videoView.layer addSublayer:playerLayer];

  // [START implement_ads_loader]
  self.adsLoader = [[IMAAdsLoader alloc] initWithSettings:nil];
  self.adsLoader.delegate = self;

  // Create an ad display container for ad rendering.
  self.adDisplayContainer =
      [[IMAAdDisplayContainer alloc] initWithAdContainer:self.videoView
                                          viewController:self
                                          companionSlots:nil];

  // Create an IMAAVPlayerVideoDisplay to give the SDK access to your video player.
  self.imaVideoDisplay = [[IMAAVPlayerVideoDisplay alloc] initWithAVPlayer:self.contentPlayer];
  // [END implement_ads_loader]
}

- (IBAction)onPlayButtonTouch:(id)sender {
  [self requestStream];
  self.playButton.hidden = YES;
}

// [START make_stream_request]
- (void)requestStream {
  // Create a stream request. Use one of "Live stream request" or "VOD request".
  // Live stream request.
  IMALiveStreamRequest *request = [[IMALiveStreamRequest alloc] initWithAssetKey:kAssetKey
                                                              adDisplayContainer:self.adDisplayContainer
                                                                    videoDisplay:self.imaVideoDisplay
                                                                     userContext:nil];
  // VOD request. Comment out the IMALiveStreamRequest above and uncomment this IMAVODStreamRequest
  // to switch from a livestream to a VOD stream.
  /*IMAVODStreamRequest *request =
      [[IMAVODStreamRequest alloc] initWithContentSourceID:kContentSourceID
                                                videoID:kVideoID
                                     adDisplayContainer:adDisplayContainer
                                           videoDisplay:imaVideoDisplay
                                            userContext:nil];*/
  [self.adsLoader requestStreamWithRequest:request];
}
// [END make_stream_request]

// [START ads_loader_delegates]
- (void)adsLoader:(IMAAdsLoader *)loader adsLoadedWithData:(IMAAdsLoadedData *)adsLoadedData {
  NSLog(@"Stream created with: %@.", adsLoadedData.streamManager.streamId);
  // adsLoadedData.streamManager is set because we made an IMAStreamRequest.
  self.streamManager = adsLoadedData.streamManager;
  self.streamManager.delegate = self;
  [self.streamManager initializeWithAdsRenderingSettings:nil];
}

- (void)adsLoader:(IMAAdsLoader *)loader failedWithErrorData:(IMAAdLoadingErrorData *)adErrorData {
  // Something went wrong loading ads. Log the error and play the content.
  NSLog(@"AdsLoader error, code:%ld, message: %@", adErrorData.adError.code,
        adErrorData.adError.message);
  [self.contentPlayer play];
}
// [END ads_loader_delegates]

// [START stream_manager_delegates]
- (void)streamManager:(IMAStreamManager *)streamManager didReceiveAdEvent:(IMAAdEvent *)event {
  NSLog(@"StreamManager event (%@).", event.typeString);
  switch (event.type) {
    case kIMAAdEvent_STARTED: {
      // Log extended data.
      NSString *extendedAdPodInfo = [[NSString alloc]
          initWithFormat:@"Showing ad %ld/%ld, bumper: %@, title: %@, description: %@, contentType:"
                         @"%@, pod index: %ld, time offset: %lf, max duration: %lf.",
                         (long)event.ad.adPodInfo.adPosition, (long)event.ad.adPodInfo.totalAds,
                         event.ad.adPodInfo.isBumper ? @"YES" : @"NO", event.ad.adTitle,
                         event.ad.adDescription, event.ad.contentType,
                         (long)event.ad.adPodInfo.podIndex, event.ad.adPodInfo.timeOffset,
                         event.ad.adPodInfo.maxDuration];

      NSLog(@"%@", extendedAdPodInfo);
      break;
    }
    case kIMAAdEvent_AD_BREAK_STARTED: {
      NSLog(@"Ad break started");
      break;
    }
    case kIMAAdEvent_AD_BREAK_ENDED: {
      NSLog(@"Ad break ended");
      break;
    }
    case kIMAAdEvent_AD_PERIOD_STARTED: {
      NSLog(@"Ad period started");
      break;
    }
    case kIMAAdEvent_AD_PERIOD_ENDED: {
      NSLog(@"Ad period ended");
      break;
    }
    default:
      break;
  }
}

- (void)streamManager:(IMAStreamManager *)streamManager didReceiveAdError:(IMAAdError *)error {
  NSLog(@"StreamManager error with type: %ld\ncode: %ld\nmessage: %@", error.type, error.code,
        error.message);
  [self.contentPlayer play];
}
// [END stream_manager_delegates]

@end
