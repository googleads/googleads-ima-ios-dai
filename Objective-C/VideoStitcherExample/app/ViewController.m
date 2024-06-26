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

typedef enum {kLiveStream, kVODStream} streamType;

/// VideoStitcher stream request type. Either kLiveStream or kVODStream.
static streamType const kRequestType = kLiveStream;

/// The live stream event ID associated with this stream in your Google Cloud project.
static NSString *const kLiveStreamEventID = @"";
/// The custom asset key associated with this stream in your Google Cloud project.
static NSString *const kCustomAssetKey = @"";

/// The VOD stream config ID associated with this stream in your Google Cloud project.
static NSString *const kVODConfigID = @"";

/// The network code of the Google Cloud account containing the Video Stitcher API project.
static NSString *const kNetworkCode = @"";
/// The project number associated with your Video Stitcher API project.
static NSString *const kProjectNumber = @"";
/// The Google Cloud region where your Video Stitcher API project is located.
static NSString *const kLocation = @"";
/// A recently generated OAuth Token for a Google Cloud service worker account with the Video
/// Stitcher API enabled.
static NSString *const kOAuthToken = @"";

/// Fallback URL in case something goes wrong in loading the stream. If all goes well, this will not
/// be used.
static NSString *const kBackupStreamURLString =
    @"http://googleimadev-vh.akamaihd.net/i/big_buck_bunny/bbb-,480p,720p,1080p,.mov.csmil/"
    @"master.m3u8";

@interface ViewController () <IMAAdsLoaderDelegate, IMAStreamManagerDelegate>

/// Content video player.
@property(nonatomic, strong) AVPlayer *contentPlayer;

/// Play button.
@property(nonatomic, weak) IBOutlet UIButton *playButton;
/// UIView in which we will render our AVPlayer for content.
@property(nonatomic, weak) IBOutlet UIView *videoView;

/// Entry point for the SDK. Used to make ad requests.
@property(nonatomic, strong) IMAAdsLoader *adsLoader;
/// Main point of interaction with the SDK. Created by the SDK as the result of an ad request.
@property(nonatomic, strong) IMAStreamManager *streamManager;

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
  // Initialize AVPlayer.
  self.contentPlayer = [[AVPlayer alloc] init];

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
  IMAAVPlayerVideoDisplay *imaVideoDisplay =
      [[IMAAVPlayerVideoDisplay alloc] initWithAVPlayer:self.contentPlayer];
  // Create a stream request.
  IMAStreamRequest *streamRequest;
  if (kRequestType == kLiveStream) {
    streamRequest =
        [[IMAVideoStitcherLiveStreamRequest alloc] initWithLiveStreamEventID:kLiveStreamEventID
                                                                      region:kLocation
                                                               projectNumber:kProjectNumber
                                                                  OAuthToken:kOAuthToken
                                                                 networkCode:kNetworkCode
                                                              customAssetKey:kCustomAssetKey
                                                          adDisplayContainer:adDisplayContainer
                                                                videoDisplay:imaVideoDisplay
                                                                 userContext:nil
                                                 videoStitcherSessionOptions:nil];
  } else {
    streamRequest =
        [[IMAVideoStitcherVODStreamRequest alloc] initWithVODConfigID:kVODConfigID
                                                               region:kLocation
                                                        projectNumber:kProjectNumber
                                                           OAuthToken:kOAuthToken
                                                          networkCode:kNetworkCode
                                                   adDisplayContainer:adDisplayContainer
                                                         videoDisplay:imaVideoDisplay
                                                          userContext:nil
                                          videoStitcherSessionOptions:nil];
  }
  [self.adsLoader requestStreamWithRequest:streamRequest];
}

#pragma mark AdsLoader Delegates

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
  // Load fallback stream.
  NSURL *contentURL = [NSURL URLWithString:kBackupStreamURLString];
  AVPlayerItem *contentPlayerItem = [AVPlayerItem playerItemWithURL:contentURL];
  [self.contentPlayer replaceCurrentItemWithPlayerItem:contentPlayerItem];
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
