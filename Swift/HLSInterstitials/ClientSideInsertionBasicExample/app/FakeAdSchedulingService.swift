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

/// A structure that represents an ad pod to the ad scheduler.
///
/// Use this structure to store unique information about an ad pod. See
/// https://developers.google.com/ad-manager/dynamic-ad-insertion/api/pod-serving/reference/live#method_hls_pod_manifest
/// for a description of the fields.
struct AdSchedulingServiceAdPodInfo {

  /// The time at which the ad pod should be inserted.
  let insertTime: Date

  /// The ID of the ad pod.
  ///
  /// This is a unique, monotonically increasing number that is assigned to each ad pod by the
  /// publisher-owned signaling server.
  let adBreakID: String

  /// The duration of the ad pod.
  let adPodDuration: CMTime

  /// The SCTE-35 signal associated with this ad pod.
  let scte35: String

  /// The custom parameters associated with this ad pod.
  let params: String

  init(
    insertTime: Date,
    adBreakID: String = "",
    adPodDuration: CMTime = CMTime(seconds: 0, preferredTimescale: 1),
    scte35: String = "",
    params: String = ""
  ) {
    self.insertTime = insertTime
    self.adBreakID = adBreakID
    self.adPodDuration = adPodDuration
    self.scte35 = scte35
    self.params = params
  }
}

/// A protocol that defines the delegate methods used by the ad scheduling service.
protocol AdSchedulingServiceDelegate {
  /// The scheduling service calls this method when there is a new ad pod to insert.
  ///
  /// Use this method to insert the HLS interstitial manifest into your player.
  ///
  /// - Parameters:
  ///   - service: The ad scheduling service that has a new ad pod to insert.
  ///   - adPodInfo: The ad pod to insert.
  ///   - manifestURL: The URL of the HLS manifest for the ad pod.
  func adSchedulingService(
    _ service: FakeAdSchedulingService, insertAdPodWithInfo adPodInfo: AdSchedulingServiceAdPodInfo,
    manifestURL: URL)

  /// The scheduling service calls this method once it is fully initialized.
  ///
  /// Displatch any known ad breaks before calling this method.
  ///
  /// - Parameter service: the ad scheduling service that is ready for playback.
  func adSchedulingServiceReadyForPlayback(_ service: FakeAdSchedulingService)
}

/// A fake ad scheduling service that generates ad pods at a fixed interval.
///
/// Use this class to test client-side HLS interstitial insertion in a basic use case, where a
/// single ad pod is inserted at a fixed interval.
class FakeAdSchedulingService {
  /// The delegate that dispatches ad pods to the player, and signals readiness for playback.
  public var delegate: AdSchedulingServiceDelegate?
  private var timer: Timer?
  private let streamID: String
  private let networkCode: String
  private let customAssetKey: String

  /// Initialize the ad scheduling service with stream-specific identifiers.
  ///
  /// At minimum, the ad scheduling service needs the network code, custom asset key and stream ID
  /// to generate the HLS manifest URL for each ad pod.
  ///
  /// - Parameters:
  ///   - networkCode: The network code of the current stream.
  ///   - customAssetKey: The custom asset key of the current stream.
  ///   - streamID: The stream ID of the current stream session.
  init(networkCode: String, customAssetKey: String, streamID: String) {
    self.networkCode = networkCode
    self.customAssetKey = customAssetKey
    self.streamID = streamID
  }

  /// Start the ad scheduling service.
  ///
  /// This method should be called after the stream manager has been initialized.
  func start() {
    // Get any known ad pods, such as those recently past or currently in progress.
    self.getKnownAdPods()

    // Poll regularly for any new upcoming ad pods.
    self.timer = Timer.scheduledTimer(
      timeInterval: 60,
      target: self,
      selector: #selector(getUpcomingAdPods),
      userInfo: nil,
      repeats: true)
  }

  /// Generate a 20-second ad pod at the start of the most recent minute.
  ///
  /// This ad pod may be in progress, or it may have recently finished.
  ///
  /// Note: In a real use case, this method would contact a publisher-owned signaling server to get
  /// information about any ad pods that are recently past, currently in progress or already
  /// scheduled to start in the near future.
  func getKnownAdPods() {
    // Generate a fake ad pod for the last minute.
    let nowInSeconds = Int(Date().timeIntervalSince1970)
    let lastMinute = nowInSeconds - (nowInSeconds % 60)
    self.generateFakeAdPod(insertTimeInSeconds: lastMinute, durationInSeconds: 20)

    // Once all known ad pods have been generated and dispatched to the delegate, signal that
    // playback can begin.
    self.delegate?.adSchedulingServiceReadyForPlayback(self)
  }

  /// Generate a 20-second ad pod at the start of the next minute.
  ///
  /// Note: In a real use case, this method would contact a publisher-owned signaling server to get
  /// information about any ad pods that are scheduled to start in the near future.
  @objc func getUpcomingAdPods() {
    // Generate a fake ad pod for the start of the next minute.
    let nowInSeconds = Int(Date().timeIntervalSince1970)
    let nextMinute = nowInSeconds - (nowInSeconds % 60) + 60
    self.generateFakeAdPod(insertTimeInSeconds: nextMinute, durationInSeconds: 20)
  }

  /// Generate a fake ad pod and send it to the delegate to be inserted.
  ///
  /// - Parameters:
  ///   - insertTimeInSeconds: the time at which the ad pod should be inserted, in seconds since the
  ///     unix epoch.
  ///   - durationInSeconds: the duration of the ad pod, in seconds.
  func generateFakeAdPod(insertTimeInSeconds: Int, durationInSeconds: Double) {
    let insertTime = Date(timeIntervalSince1970: Double(insertTimeInSeconds))
    print("Requesting ad break to start at " + insertTime.formatted())

    // In a real use case, the ad break ID would be provided by the publisher-owned signaling server.
    // This method uses the number of minutes since the unix epoch.
    let adBreakID = "BREAK_" + String(Int(insertTimeInSeconds / 60))

    let adPodDuration = CMTime(seconds: durationInSeconds, preferredTimescale: 1)

    // Build the ad pod to insert into your player and dispatch it to the delegate.
    let adPodInfo = AdSchedulingServiceAdPodInfo(
      insertTime: insertTime, adBreakID: adBreakID, adPodDuration: adPodDuration)
    let manifestURL = generateAdPodURL(adPodInfo: adPodInfo)
    self.delegate?.adSchedulingService(
      self, insertAdPodWithInfo: adPodInfo, manifestURL: manifestURL)
  }

  /// Generate the HLS manifest URL for an ad pod.
  ///
  /// See https://developers.google.com/ad-manager/dynamic-ad-insertion/api/pod-serving/reference/live#method_hls_pod_manifest
  /// for a description of the URL being generated.
  ///
  /// - Parameter adPodInfo: the ad pod to generate the manifest URL for.
  /// - Returns: the HLS manifest URL for the ad pod.
  func generateAdPodURL(adPodInfo: AdSchedulingServiceAdPodInfo) -> URL {
    let durationMS = String(Int(CMTimeGetSeconds(adPodInfo.adPodDuration) * 1000))
    let adBreakID = String(adPodInfo.adBreakID)
    let path =
      "/linear/pods/v1/hls/network/\(self.networkCode)/custom_asset/\(self.customAssetKey)/ad_break_id/\(adBreakID).m3u8"

    var components = URLComponents()
    components.scheme = "https"
    components.host = "dai.google.com"
    components.path = path
    components.queryItems = [
      URLQueryItem(name: "stream_id", value: self.streamID),
      URLQueryItem(name: "pd", value: durationMS),
      URLQueryItem(name: "scte35", value: adPodInfo.scte35),
      URLQueryItem(name: "cust_params", value: adPodInfo.params),
    ]
    return components.url!
  }
}
