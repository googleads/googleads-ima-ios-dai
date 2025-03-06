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
// [START import_ima_sdk]
import GoogleInteractiveMediaAds
// [START_EXCLUDE]
import UIKit

// [END_EXCLUDE]

class ViewController:
  UIViewController,
  IMAAdsLoaderDelegate,
  IMAStreamManagerDelegate,
  AdSchedulingServiceDelegate
{
  // [START_EXCLUDE]
  /// Google Ad Manager network code.
  static let networkCode = "YOUR_NETWORK_CODE"
  /// Livestream custom asset key.
  static let customAssetKey = "YOUR_CUSTOM_ASSET_KEY"
  /// URL of the content stream.
  static let contentStreamURLString =
    "http://devimages.apple.com/iphone/samples/bipbop/bipbopall.m3u8"
  // [END_EXCLUDE]

  /// The entry point for the IMA DAI SDK to make DAI stream requests.
  private var adsLoader: IMAAdsLoader?
  /// The container where the SDK renders each ad's user interface elements and companion slots.
  private var adDisplayContainer: IMAAdDisplayContainer?
  /// The reference of your video player for the IMA DAI SDK to monitor playback and handle timed
  /// metadata.
  private var imaVideoDisplay: IMAAVPlayerVideoDisplay!
  /// References the stream manager from the IMA DAI SDK after successful stream loading.
  private var streamManager: IMAStreamManager?
  // Manages switching between content and interstitial streams
  private var interstitialEventController: AVPlayerInterstitialEventController?

  // [START_EXCLUDE]
  /// Play button.
  @IBOutlet private weak var playButton: UIButton!

  @IBOutlet private weak var videoView: UIView!
  /// Video player to play the DAI stream for both content and ads.
  private var videoPlayer: AVPlayer!
  // [END_EXCLUDE]

  override func viewDidLoad() {
    super.viewDidLoad()

    // [START_EXCLUDE]
    playButton.layer.zPosition = CGFloat(MAXFLOAT)

    // Load AVPlayer with path to our content.
    let contentURL = URL(string: ViewController.contentStreamURLString)!
    videoPlayer = AVPlayer(url: contentURL)

    // Create an InterstitialEventController to handle interstitial events, like inserting ad pods.
    self.interstitialEventController = AVPlayerInterstitialEventController(
      primaryPlayer: videoPlayer)

    // Create a player layer for the player.
    let playerLayer = AVPlayerLayer(player: videoPlayer)

    // Size, position, and display the AVPlayer.
    playerLayer.frame = videoView.layer.bounds
    videoView.layer.addSublayer(playerLayer)
    // [END_EXCLUDE]

    adsLoader = IMAAdsLoader(settings: nil)
    adsLoader?.delegate = self

    // Create an ad display container for rendering each ad's user interface elements and companion
    // slots.
    adDisplayContainer = IMAAdDisplayContainer(
      adContainer: videoView,
      viewController: self,
      companionSlots: nil)

    // Create an IMAAVPlayerVideoDisplay to give the SDK access to your video player.
    imaVideoDisplay = IMAAVPlayerVideoDisplay(avPlayer: videoPlayer)
  }
  // [END import_ima_sdk]

  // [START make_stream_request]
  @IBAction func onPlayButtonTouch(_ sender: Any) {
    requestStream()
    playButton.isHidden = true
  }

  func requestStream() {
    // Create a livestream request.
    let request = IMAPodStreamRequest(
      networkCode: ViewController.networkCode,
      customAssetKey: ViewController.customAssetKey,
      adDisplayContainer: adDisplayContainer!,
      videoDisplay: self.imaVideoDisplay,
      pictureInPictureProxy: nil,
      userContext: nil)
    adsLoader?.requestStream(with: request)
  }
  // [END make_stream_request]

  // MARK: - IMAAdsLoaderDelegate
  // [START ads_loader_delegates]
  func adsLoader(_ loader: IMAAdsLoader, adsLoadedWith adsLoadedData: IMAAdsLoadedData) {
    print("Stream created with: \(adsLoadedData.streamManager.streamId!)")
    streamManager = adsLoadedData.streamManager!
    streamManager!.delegate = self

    // Get the stream ID.
    guard let streamID = self.streamManager?.streamId else { return }

    // Create a fake ad scheduler to simulate requesting ad break information from a publisher-owned
    // signaling server and building ad pods.
    let adScheduler = FakeAdSchedulingService(
      networkCode: ViewController.networkCode, customAssetKey: ViewController.customAssetKey,
      streamID: streamID)
    adScheduler.delegate = self
    adScheduler.start()
  }

  func adsLoader(_ loader: IMAAdsLoader, failedWith adErrorData: IMAAdLoadingErrorData) {
    print("Error loading ads: \(adErrorData.adError.message!)")
    // Play the content stream without ads.
    videoPlayer.play()
  }
  // [END ads_loader_delegates]

  // MARK: - IMAStreamManagerDelegate
  // [START stream_manager_delegates]
  func streamManager(_ streamManager: IMAStreamManager, didReceive event: IMAAdEvent) {
    print("Ad event \(event.typeString).")
    switch event.type {
    case IMAAdEventType.STARTED:
      // Log extended data.
      if let ad = event.ad {
        let extendedAdPodInfo = String(
          format: "Showing ad %zd/%zd, bumper: %@, title: %@, "
            + "description: %@, contentType:%@, pod index: %zd, "
            + "time offset: %lf, max duration: %lf.",
          ad.adPodInfo.adPosition,
          ad.adPodInfo.totalAds,
          ad.adPodInfo.isBumper ? "YES" : "NO",
          ad.adTitle,
          ad.adDescription,
          ad.contentType,
          ad.adPodInfo.podIndex,
          ad.adPodInfo.timeOffset,
          ad.adPodInfo.maxDuration)

        print("\(extendedAdPodInfo)")
      }
      break
    case IMAAdEventType.AD_BREAK_STARTED:
      print("Ad break started.")
      break
    case IMAAdEventType.AD_BREAK_ENDED:
      print("Ad break ended.")
      break
    case IMAAdEventType.AD_PERIOD_STARTED:
      print("Ad period started.")
      break
    case IMAAdEventType.AD_PERIOD_ENDED:
      print("Ad period ended.")
      break
    default:
      break
    }
  }

  func streamManager(_ streamManager: IMAStreamManager, didReceive error: IMAAdError) {
    print("StreamManager error with type: \(error.type)")
    print("code: \(error.code)")
    print("message: \(error.message ?? "Unknown Error")")
  }
  // [END stream_manager_delegates]

  // [START ad_scheduling_delegates]
  // MARK: - AdSchedulingServiceDelegate
  func adSchedulingServiceReadyForPlayback(_ service: FakeAdSchedulingService) {
    // Trigger playback when the ad scheduler is ready.
    self.videoPlayer.play()
  }

  func adSchedulingService(
    _ service: FakeAdSchedulingService,
    insertAdPodWithInfo adPodInfo: AdSchedulingServiceAdPodInfo,
    manifestURL: URL
  ) {
    // ensure that the interstitial event controller is initialized
    guard let interstitialEventController = self.interstitialEventController else { return }
    // ensure that the player has a current AVPlayerItem
    guard let primaryItem = self.videoPlayer.currentItem else { return }

    // convert timestamp to livestream player position
    let insertTime = getPlayerPosition(timestamp: adPodInfo.insertTime, player: self.videoPlayer)

    // create ad pod player item
    let interstitialPlayerItem = AVPlayerItem(url: manifestURL)

    // create interstitial event
    let interstitialEvent = AVPlayerInterstitialEvent(
      primaryItem: primaryItem,
      identifier: String(adPodInfo.adBreakID),
      time: insertTime,
      templateItems: [interstitialPlayerItem],
      restrictions: [],
      resumptionOffset: adPodInfo.adPodDuration)
    // load event into player
    interstitialEventController.events = [interstitialEvent]
  }

  // MARK: - Helper Functions

  // Convert a unix epoch time to a player position, relative to the live playhead.
  func getPlayerPosition(timestamp: Date, player: AVPlayer) -> CMTime {
    let timestampSecs: Double = timestamp.timeIntervalSince1970
    let now: Double = Double(Date().timeIntervalSince1970)
    let secondsUntil = CMTimeMakeWithSeconds(Double(timestampSecs - now), preferredTimescale: 1)
    guard let livePosition = player.currentItem?.seekableTimeRanges.last as? CMTimeRange else {
      return secondsUntil
    }
    return CMTimeAdd(CMTimeRangeGetEnd(livePosition), secondsUntil)
  }
  // [END ad_scheduling_delegates]
}
