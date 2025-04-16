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
/// Google Ad Manager network code.
static NSString *const kNetworkCode = @"YOUR_NETWORK_CODE";
/// Livestream custom asset key.
static NSString *const kCustomAssetKey = @"YOUR_CUSTOM_ASSET_KEY";
// [START custom_vtp_handler]
/// Custom VTP Handler.
///
/// Returns the stream manifest URL from the video technical partner or manifest manipulator.
static NSString *(^gCustomVTPHandler)(NSString *) = ^(NSString *streamID) {
  // Insert synchronous code here to retrieve a stream manifest URL from your video tech partner
  // or manifest manipulation server.
  // This example uses a hardcoded URL template, containing a placeholder for the stream
  // ID and replaces the placeholder with the stream ID.
  NSString *manifestUrl = @"YOUR_MANIFEST_URL_TEMPLATE";
  return [manifestUrl stringByReplacingOccurrencesOfString:@"[[STREAMID]]"
                                                withString:streamID];
};
// [END custom_vtp_handler]
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
/// UIView for the video player.
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
  // Create a stream request.
  IMAStreamRequest *request;
  if (kStreamType == StreamTypeLive) {
    // Live stream request. Replace the network code and custom asset key with your values.
    request = [[IMAPodStreamRequest alloc] initWithNetworkCode:kNetworkCode
                                                customAssetKey:kCustomAssetKey
                                            adDisplayContainer:self.adDisplayContainer
                                                  videoDisplay:self.imaVideoDisplay
                                         pictureInPictureProxy:nil
                                                   userContext:nil];
  } else {
    // VOD request. Replace the network code with your value.
    request = [[IMAPodVODStreamRequest alloc] initWithNetworkCode:kNetworkCode
                                               adDisplayContainer:self.adDisplayContainer
                                                     videoDisplay:self.imaVideoDisplay
                                            pictureInPictureProxy:nil
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

  // Build the Pod serving Stream URL.
  NSString *streamID = adsLoadedData.streamManager.streamId;
  // Your custom VTP handler takes the stream ID and returns the stream manifest URL.
  NSString *urlString = gCustomVTPHandler(streamID);
  NSURL *streamUrl = [NSURL URLWithString:urlString];
  if (kStreamType == StreamTypeLive) {
    // Load live streams directly into the AVPlayer.
    [self.imaVideoDisplay loadStream:streamUrl withSubtitles:@[]];
    [self.imaVideoDisplay play];
  } else {
    // Load VOD streams using the `loadThirdPartyStream` method in IMA SDK's stream manager.
    // The stream manager loads the stream, requests metadata, and starts playback.
    [self.streamManager loadThirdPartyStream:streamUrl streamSubtitles:@[]];
  }
}

- (void)adsLoader:(IMAAdsLoader *)loader failedWithErrorData:(IMAAdLoadingErrorData *)adErrorData {
  // Log the error and play the backup content.
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
