// Copyright 2024 Google LLC. All rights reserved.
//
//
// Licensed under the Apache License, Version 2.0 (the "License"); you may not use this
// file except in compliance with the License. You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software distributed under
// the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF
// ANY KIND, either express or implied. See the License for the specific language governing
// permissions and limitations under the License.

#import "ViewController.h"

#import <AVFoundation/AVFoundation.h>

@import GoogleInteractiveMediaAds;

typedef enum {liveStream, vodStream} streamType;
/// Specifies the ad pod stream type; either `liveStream` or `vodStream`.
static streamType const kRequestType = liveStream;
/// Google Ad Manager network code.
static NSString *const kNetworkCode = @"";
/// Livestream custom asset key.
static NSString *const kCustomAssetKey = @"";
/// Returns the stream manifest URL from the video technical partner or manifest manipulator.
static NSString *(^gCustomVTPParser)(NSString *) = ^(NSString *streamID) {
  // Insert synchronous code here to retrieve a stream manifest URL from your video tech partner
  // or manifest manipulation server.
  NSString *manifestUrl = @"";
  return manifestUrl;
};

/// Fallback URL in case something goes wrong in loading the stream. If all goes well, this will not
/// be used.
static NSString *const kBackupStreamURLString = @"";

@interface ViewController () <IMAAdsLoaderDelegate, IMAStreamManagerDelegate>

/// Content video player.
@property(nonatomic, strong) AVPlayer *contentPlayer;

// UI
/// Play button.
@property(nonatomic, weak) IBOutlet UIButton *playButton;
/// UIView in which we will render our AVPlayer for content.
@property(nonatomic, weak) IBOutlet UIView *videoView;

// SDK
/// Entry point for the SDK. Used to make ad requests.
@property(nonatomic, strong) IMAAdsLoader *adsLoader;
/// Main point of interaction with the SDK. Created by the SDK as the result of an ad request.
@property(nonatomic, strong) IMAStreamManager *streamManager;
/// Video display used by the SDK to play ads.
@property(nonatomic, strong) id<IMAVideoDisplay> videoDisplay;

@end

@implementation ViewController

- (void)viewDidLoad {
  [super viewDidLoad];

  self.playButton.layer.zPosition = MAXFLOAT;

  [self setupAdsLoader];
  [self setUpContentPlayer];
}

- (IBAction)onPlayButtonTouch:(id)sender {
  [self requestStream];
  self.playButton.hidden = YES;
}

#pragma mark Content Player Setup

- (void)setUpContentPlayer {
  // Load AVPlayer with path to our content.
  NSURL *contentURL = [NSURL URLWithString:kBackupStreamURLString];
  self.contentPlayer = [AVPlayer playerWithURL:contentURL];

  // Create a player layer for the player.
  AVPlayerLayer *playerLayer = [AVPlayerLayer playerLayerWithPlayer:self.contentPlayer];

  // Size, position, and display the AVPlayer.
  playerLayer.frame = self.videoView.layer.bounds;
  [self.videoView.layer addSublayer:playerLayer];
}

#pragma mark SDK Setup

- (void)setupAdsLoader {
  self.adsLoader = [[IMAAdsLoader alloc] initWithSettings:nil];
  self.adsLoader.delegate = self;
}

- (void)requestStream {
  // Create an ad display container for ad rendering.
  IMAAdDisplayContainer *adDisplayContainer =
      [[IMAAdDisplayContainer alloc] initWithAdContainer:self.videoView
                                          viewController:self
                                          companionSlots:nil];
  // Create an IMAAVPlayerVideoDisplay to give the SDK access to your video player.
  self.videoDisplay =
      [[IMAAVPlayerVideoDisplay alloc] initWithAVPlayer:self.contentPlayer];
  IMAStreamRequest *request;
  if (kRequestType == liveStream) {
    // Create a pod serving request for a livestream.
    request = [[IMAPodStreamRequest alloc] initWithNetworkCode:kNetworkCode
                                                customAssetKey:kCustomAssetKey
                                            adDisplayContainer:adDisplayContainer
                                                  videoDisplay:self.videoDisplay
                                         pictureInPictureProxy:nil
                                                   userContext:nil];
  } else {
    // Create a pod serving request for a VOD stream.
    request = [[IMAPodVODStreamRequest alloc] initWithNetworkCode:kNetworkCode
                                               adDisplayContainer:adDisplayContainer
                                                     videoDisplay:self.videoDisplay
                                            pictureInPictureProxy:nil
                                                      userContext:nil];
  }
  [self.adsLoader requestStreamWithRequest:request];
}

#pragma mark AdsLoader Delegates

- (void)adsLoader:(IMAAdsLoader *)loader adsLoadedWithData:(IMAAdsLoadedData *)adsLoadedData {
  // Initialize and listen to stream manager's events.
  self.streamManager = adsLoadedData.streamManager;
  // The stream manager must be initialized before playback for adsRenderingSettings to be
  // respected.
  [self.streamManager initializeWithAdsRenderingSettings:nil];
  self.streamManager.delegate = self;

  // Build the Pod serving Stream URL and load into AVPlayer
  NSString *streamId = adsLoadedData.streamManager.streamId;
  NSString *urlString = gCustomVTPParser(streamId);
  NSURL *streamUrl = [NSURL URLWithString:urlString];
  if (kRequestType == liveStream) {
    [self.videoDisplay loadStream:streamUrl withSubtitles:@[]];
    [self.videoDisplay play];
  } else {
    [self.streamManager loadThirdPartyStream:streamUrl streamSubtitles:@[]];
    // There is no need to trigger playback here.
    // streamManager.loadThirdPartyStream will load the stream, request metadata, and play
  }
  NSLog(@"Stream created with: %@.", self.streamManager.streamId);
}

- (void)adsLoader:(IMAAdsLoader *)loader failedWithErrorData:(IMAAdLoadingErrorData *)adErrorData {
  // Something went wrong loading ads. Log the error and play the content.
  NSLog(@"AdsLoader error, code:%ld, message: %@", adErrorData.adError.code,
        adErrorData.adError.message);
  [self.contentPlayer play];
}

#pragma mark StreamManager Delegates

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

@end
