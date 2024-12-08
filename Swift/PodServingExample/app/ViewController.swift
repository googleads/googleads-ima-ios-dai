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

// The main view controller for the sample app.
class ViewController: UIViewController, IMAAdsLoaderDelegate, IMAStreamManagerDelegate {
  enum StreamType { case liveStream, vodStream }
  /// Specifies the ad pod stream type; either `StreamType.liveStream` or `StreamType.vodStream`.
  static let requestType = StreamType.liveStream
  /// Google Ad Manager network code.
  static let networkCode = ""
  /// Livestream custom asset key.
  static let customAssetKey = ""
  /// Returns the stream manifest URL from the video technical partner or manifest manipulator.
  static let customVTPParser = { (streamID: String) -> (String) in
    // Insert synchronous code here to retrieve a stream manifest URL from your video tech partner
    // or manifest manipulation server.
    let manifestURL = ""
    return manifestURL
  }

  static let backupStreamURLString = ""

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
    self.videoDisplay = IMAAVPlayerVideoDisplay(avPlayer: contentPlayer!)
    let streamRequest: IMAStreamRequest
    if ViewController.requestType == StreamType.liveStream {
      // Create a pod serving live stream request.
      streamRequest = IMAPodStreamRequest(
        networkCode: ViewController.networkCode,
        customAssetKey: ViewController.customAssetKey,
        adDisplayContainer: adDisplayContainer!,
        videoDisplay: self.videoDisplay,
        pictureInPictureProxy: nil,
        userContext: nil)
    } else {
      // Create a pod serving VOD stream request.
      streamRequest = IMAPodVODStreamRequest(
        networkCode: ViewController.networkCode,
        adDisplayContainer: adDisplayContainer!,
        videoDisplay: self.videoDisplay,
        pictureInPictureProxy: nil,
        userContext: nil)
    }

    adsLoader?.requestStream(with: streamRequest)
  }

  func startMediaSession() {
    try? AVAudioSession.sharedInstance().setActive(true, options: [])
    try? AVAudioSession.sharedInstance().setCategory(.playback)
  }

  // MARK: - IMAAdsLoaderDelegate

  func adsLoader(_ loader: IMAAdsLoader, adsLoadedWith adsLoadedData: IMAAdsLoadedData) {
    self.streamManager = adsLoadedData.streamManager!
    self.streamManager?.delegate = self
    // The stream manager must be initialized before playback for adsRenderingSettings to be
    // respected.
    self.streamManager?.initialize(with: nil)
    let streamID = self.streamManager?.streamId
    let urlString = ViewController.customVTPParser(streamID!)
    let streamUrl = URL(string: urlString)
    if ViewController.requestType == StreamType.liveStream {
      self.videoDisplay.loadStream(streamUrl!, withSubtitles: [])
      self.videoDisplay.play()
    } else {
      self.streamManager?.loadThirdPartyStream(streamUrl!, streamSubtitles: [])
      // Skip calling self.videoDisplay.play() because the streamManager.loadThirdPartyStream()
      // function will play the stream as soon as loading is completed.
    }
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
