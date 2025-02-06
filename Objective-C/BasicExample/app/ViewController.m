#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>

// [START import_ima_sdk]
@import GoogleInteractiveMediaAds;

// [START_EXCLUDE]
typedef NS_ENUM(NSInteger, StreamType) {
  /// Live stream.
  StreamTypeLive,
  /// VOD.
  StreamTypeVOD,
};

/// Specifies the ad pod stream type; either `StreamTypeLive` or `StreamTypeVOD`.
///
/// Change to `StreamTypeVOD` to make a VOD request.
static StreamType const kStreamType = StreamTypeLive;
/// Live stream asset key.
static NSString *const kLiveStreamAssetKey = @"c-rArva4ShKVIAkNfy6HUQ";
/// VOD content source ID.
static NSString *const kVODContentSourceID = @"2548831";
/// VOD video ID.
static NSString *const kVODVideoID = @"tears-of-steel";
/// Network code.
static NSString *const kNetworkCode = @"21775744923";

/// The backup stream is only played when an error is detected during the stream creation.
static NSString *const kBackupContentUrl =
    @"http://devimages.apple.com/iphone/samples/bipbop/bipbopall.m3u8";
// [END_EXCLUDE]

@interface ViewController () <IMAAdsLoaderDelegate, IMAStreamManagerDelegate>
/// The entry point for the IMA DAI SDK to make DAI stream requests.
@property(nonatomic, strong) IMAAdsLoader *adsLoader;
/// The container where the SDK renders each ad's user interface elements and companion slots.
@property(nonatomic, strong) IMAAdDisplayContainer *adDisplayContainer;
/// The reference of your video player for the IMA DAI SDK to monitor playback and handle timed
/// metadata.
@property(nonatomic, strong) IMAAVPlayerVideoDisplay *imaVideoDisplay;
/// References the stream manager from the IMA DAI SDK after successful stream loading.
@property(nonatomic, strong) IMAStreamManager *streamManager;

// [START_EXCLUDE]
/// Play button.
@property(nonatomic, weak) IBOutlet UIButton *playButton;

@property(nonatomic, weak) IBOutlet UIView *videoView;
/// Video player to play the DAI stream for both content and ads.
@property(nonatomic, strong) AVPlayer *videoPlayer;
// [END_EXCLUDE]

@end

@implementation ViewController

- (void)viewDidLoad {
  [super viewDidLoad];

  // [START_EXCLUDE]
  self.playButton.layer.zPosition = MAXFLOAT;

  // Load AVPlayer with path to your content.
  NSURL *contentURL = [NSURL URLWithString:kBackupContentUrl];
  self.videoPlayer = [AVPlayer playerWithURL:contentURL];

  // Create a player layer for the player.
  AVPlayerLayer *playerLayer = [AVPlayerLayer playerLayerWithPlayer:self.videoPlayer];

  // Size, position, and display the AVPlayer.
  playerLayer.frame = self.videoView.layer.bounds;
  [self.videoView.layer addSublayer:playerLayer];
  // [END_EXCLUDE]

  self.adsLoader = [[IMAAdsLoader alloc] initWithSettings:nil];
  self.adsLoader.delegate = self;

  // Create an ad display container for rendering each ad's user interface elements and companion
  // slots.
  self.adDisplayContainer =
      [[IMAAdDisplayContainer alloc] initWithAdContainer:self.videoView
                                          viewController:self
                                          companionSlots:nil];

  // Create an IMAAVPlayerVideoDisplay to give the SDK access to your video player.
  self.imaVideoDisplay = [[IMAAVPlayerVideoDisplay alloc] initWithAVPlayer:self.videoPlayer];
}
// [END import_ima_sdk]

// [START make_stream_request]
- (IBAction)onPlayButtonTouch:(id)sender {
  [self requestStream];
  self.playButton.hidden = YES;
}

- (void)requestStream {
  // Create a stream request. Use one of "Live stream request" or "VOD request", depending on your
  // type of stream.
  IMAStreamRequest *request;
  if (kStreamType == StreamTypeLive) {
    // Live stream request. Replace the asset key with your value.
    request = [[IMALiveStreamRequest alloc] initWithAssetKey:kLiveStreamAssetKey
                                                 networkCode:kNetworkCode
                                          adDisplayContainer:self.adDisplayContainer
                                                videoDisplay:self.imaVideoDisplay
                                                 userContext:nil];
  } else {
    // VOD request. Replace the content source ID and video ID with your values.
    request = [[IMAVODStreamRequest alloc] initWithContentSourceID:kVODContentSourceID
                                                           videoID:kVODVideoID
                                                       networkCode:kNetworkCode
                                                adDisplayContainer:self.adDisplayContainer
                                                      videoDisplay:self.imaVideoDisplay
                                                       userContext:nil];
  }
  [self.adsLoader requestStreamWithRequest:request];
}
// [END make_stream_request]

// [START ads_loader_delegates]
- (void)adsLoader:(IMAAdsLoader *)loader adsLoadedWithData:(IMAAdsLoadedData *)adsLoadedData {
  NSLog(@"Stream created with: %@.", adsLoadedData.streamManager.streamId);
  self.streamManager = adsLoadedData.streamManager;
  self.streamManager.delegate = self;
  [self.streamManager initializeWithAdsRenderingSettings:nil];
}

- (void)adsLoader:(IMAAdsLoader *)loader failedWithErrorData:(IMAAdLoadingErrorData *)adErrorData {
  // Log the error and play the content.
  NSLog(@"AdsLoader error, code:%ld, message: %@", adErrorData.adError.code,
        adErrorData.adError.message);
  [self.videoPlayer play];
}
// [END ads_loader_delegates]

// [START stream_manager_delegates]
- (void)streamManager:(IMAStreamManager *)streamManager didReceiveAdEvent:(IMAAdEvent *)event {
  NSLog(@"Ad event (%@).", event.typeString);
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
  [self.videoPlayer play];
}
// [END stream_manager_delegates]

@end
