#import <Foundation/Foundation.h>

@import GoogleInteractiveMediaAds;

/// IMA iOS SDK - Secure Signals
/// Demonstrates setting an encoded secure signal string on your stream request.
@interface SecureSignalsSnippet : NSObject
@end

@implementation SecureSignalsSnippet

- (void)setSecureSignals:(IMAStreamRequest *)streamRequest  {
  // [START make_secure_signals_stream_request]
  IMASecureSignals *signals =
      [[IMASecureSignals alloc] initWithCustomData:@"My encoded signal string"];
  streamRequest.secureSignals = signals;
  // [END make_secure_signals_stream_request]
}

@end
