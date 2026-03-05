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

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
@import GoogleInteractiveMediaAds;

/// IMA iOS SDK - Enable Open Measurement
/// Registering friendly obstructions for video controls using the IMA DAI SDK for iOS to improve ad viewability scores.
@interface EnableOpenMeasurement : NSObject
@end

@implementation EnableOpenMeasurement
// [START register_obstructions]
- (void)registerObstructionsForContainer:(IMAAdDisplayContainer *)displayContainer {
    UIView *transparentTapOverlay = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 300, 250)];
    UIButton *myPauseButton = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 50, 10)];
    IMAFriendlyObstruction *overlayObstruction =
          [[IMAFriendlyObstruction alloc] initWithView:transparentTapOverlay
                                               purpose:IMAFriendlyObstructionPurposeNotVisible
                                        detailedReason:@"This overlay is transparent"];
    IMAFriendlyObstruction *pauseButtonObstruction =
          [[IMAFriendlyObstruction alloc] initWithView:myPauseButton
                                               purpose:IMAFriendlyObstructionPurposeMediaControls
                                        detailedReason:@"This is the video player pause button"];

    [displayContainer registerFriendlyObstruction:overlayObstruction];
    [displayContainer registerFriendlyObstruction:pauseButtonObstruction];
}
// [END register_obstructions]
// [START unregister_obstructions]
- (void)unregisterObstructionsForContainer:(IMAAdDisplayContainer *)displayContainer {
    // This removes all previously registered friendly obstructions from the container.
    [displayContainer unregisterAllFriendlyObstructions];
}
// [END unregister_obstructions]
@end
