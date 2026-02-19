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

import Foundation
import GoogleInteractiveMediaAds
import UIKit

/// IMA iOS SDK - Enable Open Measurement
/// Registering friendly obstructions for video controls using the IMA DAI SDK for iOS to improve ad viewability scores.
class EnableOpenMeasurement {
  // [START enable_om_sdk]
  func setupFriendlyObstructions(displayContainer: IMAAdDisplayContainer) {
    let transparentTapOverlay = UIView(frame: CGRect(x: 0, y: 0, width: 300, height: 250))
    let myPauseButton = UIButton(frame: CGRect(x: 0, y: 0, width: 50, height: 10))

    let overlayObstruction = IMAFriendlyObstruction(
      view: transparentTapOverlay,
      purpose: .notVisible,
      detailedReason: "This overlay is transparent")

    let pauseButtonObstruction = IMAFriendlyObstruction(
      view: myPauseButton,
      purpose: .mediaControls,
      detailedReason: "This is the video player pause button")

    displayContainer.register(overlayObstruction)
    displayContainer.register(pauseButtonObstruction)
  }

  func unregisterObstructions(displayContainer: IMAAdDisplayContainer) {
    displayContainer.unregisterAllFriendlyObstructions()
  }
  // [END enable_om_sdk]
}
