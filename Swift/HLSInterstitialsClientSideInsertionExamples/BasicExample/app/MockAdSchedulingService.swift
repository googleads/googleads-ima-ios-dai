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

import AVFoundation
import UIKit

struct AdPodOptions {
  var id: Int = 0
  var duration: CMTime = CMTime(seconds: 0, preferredTimescale: 1)
  var scte35: String = ""
  var params: String = ""
}

protocol AdSchedulingServiceDelegate {
  func insertAdPod(insertAt: Date, options: AdPodOptions)
}

class MockAdSchedulingService {
  private var delegate: AdSchedulingServiceDelegate
  private var timer: Timer?

  init(delegate: AdSchedulingServiceDelegate) {
    self.delegate = delegate
  }

  // Begin polling the `fireTimer` method once per second.
  func start() {
    // In a real use case, this class would communicate
    // with a publisher-owned server to receive information
    // about upcoming ad pods. This mock uses a timer instead.
    self.timer = Timer.scheduledTimer(
      timeInterval: 1.0,
      target: self,
      selector: #selector(fireTimer),
      userInfo: nil,
      repeats: true)
  }

  // This callback is fired once per second, and will request an ad pod once each minute.
  @objc func fireTimer() {
    let ts = Int(Date().timeIntervalSince1970)
    let delay = 5
    let secondsTill = 60 - ts % 60
    // Simulate receiving a message from the publisher's
    // server at the start of each minute
    if secondsTill != 60 {
      if secondsTill % 5 == 0 {
        // courtesy debug message every five seconds
        print("Making mock ad break insertion request in " + String(secondsTill) + " seconds.")
      }
    } else {
      print("Requesting ad break to start in " + String(delay) + " seconds.")
      // Setting the insertion time for 5 seconds in the future
      // to allow for load times, buffer, etc
      let insertTime = Date(timeIntervalSince1970: Double(ts + delay))
      let duration = CMTime(seconds: 20, preferredTimescale: 1)

      // in a real use case, the details of the ad break would
      // be provided by the publisher-owned scheduling server.
      // This mock uses the number of minutes since the unix
      // epoch as the ad pod ID, and sets a fixed ad duration.
      let options = AdPodOptions(id: Int(ts / 60), duration: duration)

      // initiate the ad pod insertion process
      self.delegate.insertAdPod(insertAt: insertTime, options: options)
    }
  }
}
