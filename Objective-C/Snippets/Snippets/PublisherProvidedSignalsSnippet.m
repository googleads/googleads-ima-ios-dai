// Copyright 2026 Google LLC. All rights reserved.
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

#import <GoogleInteractiveMediaAds/GoogleInteractiveMediaAds.h>
#import <Foundation/Foundation.h>

@interface PublisherProvidedSignalsSnippet : NSObject
- (void)addPublisherProvidedSignalsTo:(IMAStreamRequest *)streamRequest;
@end

@implementation PublisherProvidedSignalsSnippet

// Example function to demonstrate adding Publisher Provided Signals to an existing stream request
- (void)addPublisherProvidedSignalsTo:(IMAStreamRequest *)streamRequest {
    if (!streamRequest) {
        NSLog(@"Error: streamRequest cannot be nil");
        return;
    }

    // [START pps]
    NSString *userSignalsJSON = @"{"
        @"\"PublisherProvidedTaxonomySignals\": ["
            @"{"
                @"\"taxonomy\": \"IAB_AUDIENCE_1_1\","
                @"\"values\": ["
                    @"\"6\","
                    @"\"284\""
                    // "6" = "Demographic | Age Range | 30-34"
                    // "284" = "Interest | Business and Finance |  Mergers and Acquisitions"
                @"]"
            @"},"
            @"{"
                @"\"taxonomy\": \"IAB_CONTENT_2_2\","
                @"\"values\": [\"49\", \"138\"]"
                // "49" = "Books and Literature | Poetry"
                // "138" = "Education | College Education | College Planning"
            @"}"
        @"],"
        @"\"PublisherProvidedStructuredSignals\": ["
            @"{"
                @"\"type\": \"audio_feed\","
                @"\"single_value\": \"af_1\""
            @"},"
            @"{"
                @"\"type\": \"delivery\","
                @"\"values\": [\"cd_1\", \"cd_3\"]"
            @"}"
        @"]"
    @"}";
    // [END pps]
    // [START pps_stream_request]
    - (NSString *)encodeSignals:(NSString *)jsonString {
        // Encode the JSON string to URL-safe Base64.
        NSData *data = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
        if (!data) {
            NSLog(@"Error: Could not convert JSON string to data");
            return nil;
        }

        NSString *base64Signals = [data base64EncodedStringWithOptions:0];
        NSString *encodedSignals = [base64Signals stringByReplacingOccurrencesOfString:@"+" withString:@"%2B"];
        encodedSignals = [encodedSignals stringByReplacingOccurrencesOfString:@"/" withString:@"%2F"];
        encodedSignals = [encodedSignals stringByReplacingOccurrencesOfString:@"=" withString:@"%3D"];
        return encodedSignals;
    }

    NSString *encodedSignals = [self encodeSignals:userSignalsJSON];

    if (encodedSignals) {
        // Add the encoded signals to the stream request's ad tag parameters.
        NSMutableDictionary<NSString *, NSString *> *adTagParameters = streamRequest.adTagParameters ? [streamRequest.adTagParameters mutableCopy] : [NSMutableDictionary dictionary];
        adTagParameters[@"ppsj"] = encodedSignals;
        streamRequest.adTagParameters = adTagParameters;
        NSLog(@"Successfully added encoded PPSJ to adTagParameters");
    } else {
        NSLog(@"Error encoding user signals");
    }
    // [END pps_stream_request]
}

@end
