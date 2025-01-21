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

class ViewController: UIViewController, IMAAdsLoaderDelegate, IMAStreamManagerDelegate {
  // [START_EXCLUDE]
  enum StreamType { case live, vod }

  /// Specifies the ad pod stream type; either `StreamType.live` or `StreamType.vod`.
  ///
  /// Change to `StreamType.vod` to make a VOD request.
  static let requestType = StreamType.live
  /// Live stream asset key.
  static let assetKey = "c-rArva4ShKVIAkNfy6HUQ"
  /// VOD content source ID.
  static let contentSourceID = "2548831"
  /// VOD video ID.
  static let videoID = "tears-of-steel"

  /// The backup stream is only played when an error is detected during the stream creation.
  static let backupStreamURLString =
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

  // [START_EXCLUDE]
  /// Play button.
  @IBOutlet private weak var playButton: UIButton!

  @IBOutlet private weak var videoView: UIView!
  /// Video player to play the DAI stream for both content and ads.
  private var videoPlayer: AVPlayer?
  // [END_EXCLUDE]

  override func viewDidLoad() {
    super.viewDidLoad()

    // [START_EXCLUDE]
    playButton.layer.zPosition = CGFloat(MAXFLOAT)

    // Load AVPlayer with path to our content.
    let contentURL = URL(string: ViewController.backupStreamURLString)!
    videoPlayer = AVPlayer(url: contentURL)

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
    // Create a stream request. Use one of "Livestream request" or "VOD request".
    if ViewController.requestType == StreamType.live {
      // Livestream request.
      let request = IMALiveStreamRequest(
        assetKey: ViewController.assetKey,
        adDisplayContainer: adDisplayContainer!,
        videoDisplay: imaVideoDisplay,
        userContext: nil)
      adsLoader?.requestStream(with: request)
    } else {
      // VOD stream request.
      let request = IMAVODStreamRequest(
        contentSourceID: ViewController.contentSourceID,
        videoID: ViewController.videoID,
        adDisplayContainer: adDisplayContainer!,
        videoDisplay: imaVideoDisplay,
        userContext: nil)
      adsLoader?.requestStream(with: request)
    }
  }
  // [END make_stream_request]

  // MARK: - IMAAdsLoaderDelegate
  // [START ads_loader_delegates]
  func adsLoader(_ loader: IMAAdsLoader, adsLoadedWith adsLoadedData: IMAAdsLoadedData) {
    print("Stream created with: \(String(describing: adsLoadedData.streamManager!.streamID))")
    streamManager = adsLoadedData.streamManager!
    streamManager!.delegate = self
    streamManager!.initialize(with: nil)
  }

  func adsLoader(_ loader: IMAAdsLoader, failedWith adErrorData: IMAAdLoadingErrorData) {
    print("Error loading ads: \(String(describing: adErrorData.adError.message))")
    let streamURL = URL(string: ViewController.backupStreamURLString)
    videoPlayer.play()
  }
  // [END ads_loader_delegates]

  // MARK: - IMAStreamManagerDelegate
  // [START stream_manager_delegates]
  func streamManager(_ streamManager: IMAStreamManager, didReceive event: IMAAdEvent) {
    print("Ad event \(event.typeString).")
    switch event.type {
    case IMAAdEventType.STREAM_STARTED:
      self.startMediaSession()
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
    print("StreamManager error with type: \(error.type ?? "Unknown Error")")
    print("code: \(error.code ?? "Unknown Error")")
    print("message: \(error.message ?? "Unknown Error")")
  }
  // [END stream_manager_delegates]
}
