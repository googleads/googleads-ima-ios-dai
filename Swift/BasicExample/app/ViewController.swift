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
import GoogleInteractiveMediaAds
import UIKit

class ViewController: UIViewController, IMAAdsLoaderDelegate, IMAStreamManagerDelegate {
  enum StreamType { case liveStream, vodStream }
  // Stream request type. Either `StreamType.liveStream` or `StreamType.vodStream`.
  static let requestType = StreamType.liveStream
  // Live stream asset keys.
  static let assetKey = "c-rArva4ShKVIAkNfy6HUQ"
  // VOD content source and video ID.
  static let contentSourceID = "2548831"
  static let videoID = "tears-of-steel"
  // Backup content URL
  static let backupStreamURLString = """
    http://googleimadev-vh.akamaihd.net/i/big_buck_bunny/\
    bbb-,480p,720p,1080p,.mov.csmil/master.m3u8
    """

  private var adsLoader: IMAAdsLoader?
  private var videoDisplay: IMAAVPlayerVideoDisplay!
  private var adDisplayContainer: IMAAdDisplayContainer?
  private var streamManager: IMAStreamManager?
  private var contentPlayhead: IMAAVPlayerContentPlayhead?
  private var playerViewController: AVPlayerViewController!
  private var userSeekTime = 0.0
  private var adBreakActive = false

  private var contentPlayer: AVPlayer?
  @IBOutlet private weak var playButton: UIButton!
  @IBOutlet private weak var videoView: UIView!

  override func viewDidLoad() {
    super.viewDidLoad()

    playButton.layer.zPosition = CGFloat(MAXFLOAT)

    setupAdsLoader()
    setUpPlayer()
  }

  @IBAction func onPlayButtonTouch(_ sender: Any) {
    requestStream()
    playButton.isHidden = true
  }

  // MARK: Content Player Setup

  func setUpPlayer() {
    // Load AVPlayer with path to our content.
    contentPlayer = AVPlayer()

    // Create a player layer for the player.
    let playerLayer = AVPlayerLayer(player: contentPlayer)

    // Size, position, and display the AVPlayer.
    playerLayer.frame = videoView.layer.bounds
    videoView.layer.addSublayer(playerLayer)
  }

  // MARK: SDK Setup

  func setupAdsLoader() {
    adsLoader = IMAAdsLoader(settings: nil)
    adsLoader?.delegate = self
  }

  func requestStream() {
    // Create an ad display container for ad rendering.
    adDisplayContainer = IMAAdDisplayContainer(
      adContainer: videoView,
      viewController: self,
      companionSlots: nil)
    // Create an IMAAVPlayerVideoDisplay to give the SDK access to your video player.
    let imaVideoDisplay = IMAAVPlayerVideoDisplay(avPlayer: contentPlayer!)
    // Create a stream request. Use one of "Livestream request" or "VOD request".
    if ViewController.requestType == StreamType.liveStream {
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

  func startMediaSession() {
    try? AVAudioSession.sharedInstance().setActive(true, options: [])
    try? AVAudioSession.sharedInstance().setCategory(.playback)
  }

  // MARK: - IMAAdsLoaderDelegate

  func adsLoader(_ loader: IMAAdsLoader, adsLoadedWith adsLoadedData: IMAAdsLoadedData) {
    streamManager = adsLoadedData.streamManager!
    streamManager!.delegate = self
    streamManager!.initialize(with: nil)
  }

  func adsLoader(_ loader: IMAAdsLoader, failedWith adErrorData: IMAAdLoadingErrorData) {
    print("Error loading ads: \(String(describing: adErrorData.adError.message))")
    let streamURL = URL(string: ViewController.backupStreamURLString)
    videoDisplay.loadStream(streamURL!, withSubtitles: [])
    videoDisplay.play()
    playerViewController.player?.play()
  }

  // MARK: - IMAStreamManagerDelegate
  func streamManager(_ streamManager: IMAStreamManager, didReceive event: IMAAdEvent) {
    print("StreamManager event \(event.typeString).")
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
      // Trigger an update to send focus to the ad display container.
      adBreakActive = true
      break
    case IMAAdEventType.AD_BREAK_ENDED:
      // Trigger an update to send focus to the content player.
      adBreakActive = false
      break
    case IMAAdEventType.ICON_FALLBACK_IMAGE_CLOSED:
      // Resume playback after the user has closed the dialog.
      self.videoDisplay.play()
      break
    default:
      break
    }
  }

  func streamManager(_ streamManager: IMAStreamManager, didReceive error: IMAAdError) {
    print("StreamManager error: \(error.message ?? "Unknown Error")")
  }

  // MARK: - AVPlayerViewControllerDelegate
  func playerViewController(
    _ playerViewController: AVPlayerViewController,
    timeToSeekAfterUserNavigatedFrom oldTime: CMTime,
    to targetTime: CMTime
  ) -> CMTime {
    if adBreakActive {
      return oldTime
    }
    return targetTime
  }
}
