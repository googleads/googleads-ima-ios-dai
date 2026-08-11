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
import SwiftUI
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
  /// Full-service DAI live stream asset key.
  static let assetKey = "c-rArva4ShKVIAkNfy6HUQ"
  /// VOD content source ID.
  static let contentSourceID = "2548831"
  /// Full-service DAI VOD stream video ID.
  static let videoID = "tears-of-steel"
  /// Network code for your Google Ad Manager account.
  static let networkCode = "21775744923"

  /// The backup stream to play when there is an error creating a DAI stream request.
  static let backupStreamURLString =
    "http://devimages.apple.com/iphone/samples/bipbop/bipbopall.m3u8"
  // [END_EXCLUDE]

  /// The entry point for the IMA DAI SDK to make DAI stream requests.
  private var adsLoader: IMAAdsLoader?
  /// The container where the SDK renders each ad's user interface elements and companion slots.
  private var adDisplayContainer: IMAAdDisplayContainer?
  /// The reference of your video player for the IMA DAI SDK to monitor playback and handle timed
  /// metadata.
  private var videoDisplay: IMAAVPlayerVideoDisplay!
  /// References the stream manager from the IMA DAI SDK after successfully loading the DAI stream.
  private var streamManager: IMAStreamManager?

  // [START_EXCLUDE]
  @IBOutlet private weak var playButton: UIButton!

  @IBOutlet private weak var videoView: UIView!
  /// Video player to play the full-service DAI stream with both content and ads stitched together.
  private var videoPlayer: AVPlayer!
  // [END_EXCLUDE]

  private var customUIView: CustomUIView?
  private var hostingControllerCustomUIView: UIHostingController<CustomUIView>?
  private var customUIDataModel: CustomUIDataModel?
  private var streamRequested: Bool = false

  var contentRateContext: UInt8 = 1
  var contentDurationContext: UInt8 = 2

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

    let controller: ViewController = self
    controller.videoPlayer.addPeriodicTimeObserver(
      forInterval: CMTimeMake(value: 1, timescale: 30),
      queue: nil,
      using: { [weak self] (time: CMTime) -> Void in
        if self?.videoPlayer != nil, let item = self?.videoPlayer!.currentItem {
          let duration = controller.getPlayerItemDuration(item)
          controller.updatePlayheadWithTime(time, duration: duration)
        }
      })
    videoPlayer.addObserver(
      self,
      forKeyPath: "rate",
      options: NSKeyValueObservingOptions.new,
      context: &contentRateContext)
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(ViewController.contentDidFinishPlaying(_:)),
      name: NSNotification.Name.AVPlayerItemDidPlayToEndTime,
      object: videoPlayer.currentItem)

    adsLoader = IMAAdsLoader(settings: nil)
    adsLoader?.delegate = self

    // Create an ad display container for rendering ad UI elements and the companion ad.
    adDisplayContainer = IMAAdDisplayContainer(
      adContainer: videoView,
      viewController: self,
      companionSlots: nil)

    // Create an IMAAVPlayerVideoDisplay to give the SDK access to your video player.
    videoDisplay = IMAAVPlayerVideoDisplay(avPlayer: videoPlayer)
  }
  // [END import_ima_sdk]

  // [START make_stream_request]
  @IBAction func onPlayButtonTouch(_ sender: Any) {
    if streamRequested {
      self.videoPlayer.play()
    } else {
      streamRequested = true
      requestStream()
    }
  }

  func requestStream() {
    let uiOptions = IMACustomUIOptions()
    uiOptions.isSkippableSupported = true
    uiOptions.isAboutThisAdSupported = true
    // Create a stream request. Use one of "Livestream request" or "VOD request".
    if ViewController.requestType == StreamType.live {
      // Livestream request.
      let request = IMALiveStreamRequest(
        assetKey: ViewController.assetKey,
        networkCode: ViewController.networkCode,
        adDisplayContainer: adDisplayContainer!,
        videoDisplay: videoDisplay,
        userContext: nil)
      request.customUIOptions = uiOptions
      adsLoader?.requestStream(with: request)
    } else {
      // VOD stream request.
      let request = IMAVODStreamRequest(
        contentSourceID: ViewController.contentSourceID,
        videoID: ViewController.videoID,
        networkCode: ViewController.networkCode,
        adDisplayContainer: adDisplayContainer!,
        videoDisplay: videoDisplay,
        userContext: nil)
      request.customUIOptions = uiOptions
      adsLoader?.requestStream(with: request)
    }
  }
  // [END make_stream_request]

  // MARK: - IMAAdsLoaderDelegate
  // [START ads_loader_delegates]
  func adsLoader(_ loader: IMAAdsLoader, adsLoadedWith adsLoadedData: IMAAdsLoadedData) {
    print("DAI stream loaded. Stream session ID: \(adsLoadedData.streamManager!.streamId!)")
    streamManager = adsLoadedData.streamManager!
    streamManager!.delegate = self
    streamManager!.initialize(with: nil)
  }

  func adsLoader(_ loader: IMAAdsLoader, failedWith adErrorData: IMAAdLoadingErrorData) {
    print("Error loading DAI stream. Error message: \(adErrorData.adError.message!)")
    // Play the backup stream.
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
    case IMAAdEventType.SHOW_AD_UI:
      print("Show ad UI.")
      if let customUI = event.customUI, let ad = event.ad {
        showAdUI(customUI, ad: ad)
      }
      break
    case IMAAdEventType.HIDE_AD_UI:
      print("Hide ad UI.")
      hideAdUI()
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

  func showAdUI(_ customUI: IMACustomUI, ad: IMAAd) {
    self.customUIDataModel = CustomUIDataModel()
    self.customUIView = CustomUIView(
      customUI: customUI, ad: ad, videoView: videoView, dataModel: self.customUIDataModel!)
    let hostingController = UIHostingController(rootView: self.customUIView!)
    videoView.addSubview(hostingController.view)
    hostingController.view.translatesAutoresizingMaskIntoConstraints = false
    hostingController.view.backgroundColor = .clear
    NSLayoutConstraint.activate([
      hostingController.view.topAnchor.constraint(
        equalTo: videoView.safeAreaLayoutGuide.topAnchor),
      hostingController.view.leadingAnchor.constraint(
        equalTo: videoView.safeAreaLayoutGuide.leadingAnchor),
      hostingController.view.trailingAnchor.constraint(
        equalTo: videoView.safeAreaLayoutGuide.trailingAnchor),
      hostingController.view.bottomAnchor.constraint(
        equalTo: videoView.safeAreaLayoutGuide.bottomAnchor),
    ])
    self.hostingControllerCustomUIView = hostingController
    hostingController.didMove(toParent: self)
    self.videoView.bringSubviewToFront(playButton)
  }

  func hideAdUI() {
    self.hostingControllerCustomUIView?.willMove(toParent: nil)
    self.hostingControllerCustomUIView?.view.removeFromSuperview()
    self.hostingControllerCustomUIView?.removeFromParent()
    self.customUIView = nil
    self.customUIDataModel = nil
  }

  // [END custom_ui]

  // Updates play button for provided playback state.
  func updatePlayheadState(_ isPlaying: Bool) {
    playButton.isHidden = isPlaying
  }

  // Notify IMA SDK when content is done for post-rolls.
  @objc func contentDidFinishPlaying(_ notification: Notification) {
    if (notification.object as? AVPlayerItem) == videoPlayer!.currentItem {
      adsLoader?.contentComplete()
    }
  }

  // Handler for keypath listener that is added for content playhead observer.
  override func observeValue(
    forKeyPath keyPath: String?,
    of object: Any?,
    change: [NSKeyValueChangeKey: Any]?,
    context: UnsafeMutableRawPointer?
  ) {
    if context == &contentRateContext && videoPlayer == object as? AVPlayer {
      updatePlayheadState(videoPlayer!.rate != 0)
    }
  }

  // Used to track progress of ads for progress bar.
  func adDidProgressToTime(_ mediaTime: TimeInterval, totalTime: TimeInterval) {
    let time = CMTimeMakeWithSeconds(mediaTime, preferredTimescale: 1000)
    let duration = CMTimeMakeWithSeconds(totalTime, preferredTimescale: 1000)
    updatePlayheadWithTime(time, duration: duration)
  }

  // Get the duration value from the player item.
  func getPlayerItemDuration(_ item: AVPlayerItem) -> CMTime {
    var itemDuration = CMTime.invalid
    if item.responds(to: #selector(getter: CAMediaTiming.duration)) {
      itemDuration = item.duration
    } else {
      if item.asset.responds(to: #selector(getter: CAMediaTiming.duration)) {
        itemDuration = item.duration
      }
    }
    return itemDuration
  }

  // Updates progress bar for provided time and duration.
  func updatePlayheadWithTime(_ time: CMTime, duration: CMTime) {
    if !CMTIME_IS_VALID(time) {
      return
    }
    let currentTime = CMTimeGetSeconds(time)
    if currentTime.isNaN {
      return
    }
    self.customUIDataModel?.currentTime = currentTime
    self.customUIView?.onProgress()
  }
}
