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
class ViewController:
  UIViewController,
  IMAAdsLoaderDelegate,
  IMAStreamManagerDelegate,
  AdSchedulingServiceDelegate
{
  /// Google Ad Manager network code.
  static let networkCode = ""
  /// Livestream custom asset key.
  static let customAssetKey = ""
  /// URL of the content stream.
  static let contentStreamURLString = ""

  private var adsLoader: IMAAdsLoader?
  private var interstitialEventController: AVPlayerInterstitialEventController?
  private var videoDisplay: IMAAVPlayerVideoDisplay!
  private var adDisplayContainer: IMAAdDisplayContainer?
  private var streamManager: IMAStreamManager?
  private var contentPlayhead: IMAAVPlayerContentPlayhead?
  private var playerViewController: AVPlayerViewController!
  private var streamID = ""
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
    // Create an InterstitialEventController to handle interstitial events, like inserting ad pods.
    self.interstitialEventController = AVPlayerInterstitialEventController(
      primaryPlayer: contentPlayer!)
    // Create an ad display container for ad rendering.
    adDisplayContainer = IMAAdDisplayContainer(
      adContainer: videoView,
      viewController: self,
      companionSlots: nil)
    // Create an IMAAVPlayerVideoDisplay to give the SDK access to your video player.
    self.videoDisplay = IMAAVPlayerVideoDisplay(avPlayer: contentPlayer!)
    let streamRequest = IMAPodStreamRequest(
      networkCode: ViewController.networkCode,
      customAssetKey: ViewController.customAssetKey,
      adDisplayContainer: adDisplayContainer!,
      videoDisplay: self.videoDisplay,
      pictureInPictureProxy: nil,
      userContext: nil)
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
    // Save the stream ID for later use.
    self.streamID = (self.streamManager?.streamId)!
    // Load the content stream and start playback.
    let streamUrl = URL(string: ViewController.contentStreamURLString)
    self.videoDisplay.loadStream(streamUrl!, withSubtitles: [])
    self.videoDisplay.play()
  }

  func adsLoader(_ loader: IMAAdsLoader, failedWith adErrorData: IMAAdLoadingErrorData) {
    print("Error loading ads: \(String(describing: adErrorData.adError.message))")
    let streamURL = URL(string: ViewController.contentStreamURLString)
    videoDisplay.loadStream(streamURL!, withSubtitles: [])
    videoDisplay.play()
  }

  // MARK: - IMAStreamManagerDelegate
  func streamManager(_ streamManager: IMAStreamManager, didReceive event: IMAAdEvent) {
    print("StreamManager event \(event.typeString).")
    switch event.type {
    case IMAAdEventType.STREAM_STARTED:
      // Create a mock ad scheduler to simulate ad scheduling.
      let adScheduler = MockAdSchedulingService(delegate: self)
      // Start the ad scheduler to insert ads once each minute.
      adScheduler.start()

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

  // MARK: - AdSchedulingServiceDelegate
  func insertAdPod(insertAt: Date, options: AdPodOptions) {
    // convert timestamp to livestream player position
    let insertTime = getPlayerPosition(timestamp: insertAt, player: self.contentPlayer!)

    let adPodURL = buildAdPodRequest(
      networkCode: ViewController.networkCode,
      customAssetKey: ViewController.customAssetKey,
      streamID: self.streamID,
      options: options)

    // create ad pod player item
    let interstitialPlayerItem = AVPlayerItem(url: adPodURL)

    // create interstitial event
    let interstitialEvent = AVPlayerInterstitialEvent(
      primaryItem: (self.contentPlayer?.currentItem!)!,
      identifier: String(options.id),
      time: insertTime,
      templateItems: [interstitialPlayerItem],
      restrictions: [],
      resumptionOffset: options.duration)
    // load event into player
    interstitialEventController!.events = [interstitialEvent]
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

  // Build the ad pod request URL from the component parameters
  func buildAdPodRequest(
    networkCode: String, customAssetKey: String, streamID: String, options: AdPodOptions
  ) -> URL {
    let durationMS = String(Int(CMTimeGetSeconds(options.duration) * 1000))
    var path = "/linear/pods/v1/hls"
    path += "/network/" + networkCode
    path += "/custom_asset/" + customAssetKey
    path += "/pod/" + String(options.id) + ".m3u8"

    var components = URLComponents()
    components.scheme = "https"
    components.host = "dai.google.com"
    components.path = path
    components.queryItems = [
      URLQueryItem(name: "stream_id", value: streamID),
      URLQueryItem(name: "pd", value: durationMS),
      URLQueryItem(name: "scte35", value: options.scte35),
      URLQueryItem(name: "cust_params", value: options.params),
    ]
    return components.url!
  }
}
