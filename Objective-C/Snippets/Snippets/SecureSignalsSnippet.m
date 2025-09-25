#import <AVKit/AVKit.h>
#import "SecureSignalsSnippet.h"

// [START import_ima_sdk]
@import GoogleInteractiveMediaAds;

typedef NS_ENUM(NSInteger, StreamType) {
  StreamTypeLive,
  StreamTypeVOD,
};

static StreamType const kStreamType = StreamTypeLive;
static NSString *const kLiveStreamAssetKey = @"c-rArva4ShKVIAkNfy6HUQ";
static NSString *const kVODContentSourceID = @"2548831";
static NSString *const kVODVideoID = @"tears-of-steel";
static NSString *const kNetworkCode = @"21775744923";

/// IMA iOS SDK - Secure Signals
/// Demonstrates setting an encoded secure signal string on your stream request.
@interface SecureSignalsSnippet ()
@property(nonatomic, strong) IMAAdsLoader *adsLoader;
@property(nonatomic, strong) IMAAdDisplayContainer *adDisplayContainer;
@property(nonatomic, strong) IMAAVPlayerVideoDisplay *videoDisplay;
@end

@implementation SecureSignalsSnippet

// [START make_secure_signals_stream_request]
- (void)requestStream {
  // Create a stream request. Use one of "Livestream request" or "VOD request",
  //  depending on your type of stream.
  IMAStreamRequest *request;
  if (kStreamType == StreamTypeLive) {
    // Livestream request. Replace the asset key with your value.
    request = [[IMALiveStreamRequest alloc] initWithAssetKey:kLiveStreamAssetKey
                                                 networkCode:kNetworkCode
                                          adDisplayContainer:self.adDisplayContainer
                                                videoDisplay:self.videoDisplay
                                                 userContext:nil];
  } else {
    // VOD request. Replace the content source ID and video ID with your values.
    request = [[IMAVODStreamRequest alloc] initWithContentSourceID:kVODContentSourceID
                                                           videoID:kVODVideoID
                                                       networkCode:kNetworkCode
                                                adDisplayContainer:self.adDisplayContainer
                                                      videoDisplay:self.videoDisplay
                                                       userContext:nil];
  }
  IMASecureSignals *signals =
      [[IMASecureSignals alloc] initWithCustomData:@"My encoded signal string"];
  request.secureSignals = signals;
  [self.adsLoader requestStreamWithRequest:request];
}
// [START make_secure_signals_stream_request]

@end
