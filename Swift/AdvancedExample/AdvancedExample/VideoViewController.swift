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
import Combine
import GoogleInteractiveMediaAds
import UIKit

protocol VideoViewControllerDelegate: AnyObject {
  func videoViewController(
    _ viewController: VideoViewController, didReportBookmarkedTime bookmarkTime: TimeInterval,
    for stream: Stream)
}

class VideoViewController: UIViewController,
  IMAAdsLoaderDelegate,
  IMAStreamManagerDelegate,
  UITextViewDelegate
{

  // MARK: - UI Outlets
  @IBOutlet var videoView: UIView!
  @IBOutlet var videoControls: UIToolbar!
  @IBOutlet var playHeadButton: UIButton!
  @IBOutlet var consoleView: UITextView!
  @IBOutlet var topLabel: UILabel!
  @IBOutlet var progressBar: UISlider!
  @IBOutlet var playHeadTimeText: UILabel!
  @IBOutlet var durationTimeText: UILabel!

  var stream: Stream?
  weak var delegate: VideoViewControllerDelegate?
  var adsLoader: IMAAdsLoader?

  private let playBtnBG = UIImage(named: "play.png")
  private let pauseBtnBG = UIImage(named: "pause.png")
  private let contentPlayer = AVPlayer()
  private var contentPlayerLayer: AVPlayerLayer!
  private var imaVideoDisplay: IMAAVPlayerVideoDisplay!
  private var streamManager: IMAStreamManager?
  private var playHeadObserver: Any?
  private var cancellables = Set<AnyCancellable>()

  private var portraitVideoViewFrame: CGRect = .zero
  private var portraitVideoViewBounds: CGRect = .zero
  private var portraitControlsViewFrame: CGRect = .zero
  private var portraitControlsViewBounds: CGRect = .zero
  private var fullScreenControlsFrame: CGRect = .zero
  private var isFullScreen = false
  private var isStreamPlaying = false
  private var isAdPlaying = false
  private var hideControlsWorkItem: DispatchWorkItem?
  private var isStatusBarHidden = false

  private var currentlySeeking = false
  private var seekStartTime: TimeInterval = 0
  private var seekEndTime: TimeInterval = 0
  private var snapbackMode = false
  private var trackingContent = false

  private var isContentPlaying: Bool { contentPlayer.rate != 0 }

  // Bookmark related properties
  private var bookmarkStreamTime: TimeInterval?
  private var pendingBookmarkSeek = false

  // MARK: - Lifecycle
  override func viewDidLoad() {
    super.viewDidLoad()

    // The stream is required to request ads, so return early if it is nil.
    guard let stream else {
      logMessage("Error: Stream is nil.")
      return
    }
    topLabel.text = stream.name
    consoleView.isEditable = false

    if stream is LiveStream {
      videoControls.isHidden = true
    }

    consoleView.delegate = self
    consoleView.contentInsetAdjustmentBehavior = .never

    portraitVideoViewFrame = videoView.frame
    portraitVideoViewBounds = videoView.bounds
    portraitControlsViewFrame = videoControls.frame
    portraitControlsViewBounds = videoControls.bounds

    view.bringSubviewToFront(videoView)
    view.bringSubviewToFront(videoControls)

    if let windowScene = view.window?.windowScene, windowScene.interfaceOrientation.isLandscape {
      viewDidEnterLandscape()
    }

    adsLoader?.delegate = self
    setUpContentPlayer()
    updatePlayHeadState(isPlaying: false)
    progressBar.value = 0
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    contentPlayerLayer?.frame = videoView.bounds
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    pendingBookmarkSeek = false
    bookmarkStreamTime = nil
    requestStream()
  }

  // MARK: - Bookmark Saving
  // [START save_bookmark_example]
  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    contentPlayer.pause()
    if isMovingFromParent {
      // Only save bookmark if we're playing a VOD stream.
      if let vodStream = stream as? VODStream, let streamManager = streamManager {
        let contentTime = streamManager.contentTime(
          forStreamTime: contentPlayer.currentTime().seconds)
        if contentTime.isFinite, contentTime > 0 {
          delegate?.videoViewController(self, didReportBookmarkedTime: contentTime, for: vodStream)
        }
      }
      if trackingContent {
        removeContentPlayerObservers()
      }
      streamManager?.destroy()
      adsLoader?.contentComplete()
      streamManager = nil
      adsLoader = nil
    }
  }
  // [END save_bookmark_example]

  deinit {
    removeContentPlayerObservers()
  }

  func setUpContentPlayer() {
    let videoTapRecognizer = UITapGestureRecognizer(
      target: self, action: #selector(showFullScreenControls(_:)))
    videoView.addGestureRecognizer(videoTapRecognizer)
    contentPlayerLayer = AVPlayerLayer(player: contentPlayer)
    contentPlayerLayer.frame = videoView.layer.bounds
    contentPlayerLayer.videoGravity = .resizeAspect
    videoView.layer.addSublayer(contentPlayerLayer)
  }

  func addContentPlayerObservers() {
    guard !trackingContent else { return }
    trackingContent = true
    playHeadObserver = contentPlayer.addPeriodicTimeObserver(
      forInterval: CMTime(value: 1, timescale: 30), queue: .main
    ) { [weak self] time in
      guard let self, let currentItem = self.contentPlayer.currentItem else { return }
      self.updatePlayHead(with: time, duration: currentItem.duration)
    }

    contentPlayer.publisher(for: \.rate)
      .receive(on: DispatchQueue.main)
      .sink { [weak self] _ in
        guard let self = self else { return }
        self.isStreamPlaying = self.isContentPlaying
        self.updatePlayHeadState(isPlaying: self.isStreamPlaying)
      }
      .store(in: &cancellables)

    contentPlayer.publisher(for: \.currentItem)
      .compactMap { $0 }
      .flatMap { currentItem in
        currentItem.publisher(for: \.duration)
      }
      .receive(on: DispatchQueue.main)
      .sink { [weak self] newDuration in
        guard let self = self else { return }
        self.updatePlayHeadDuration(with: newDuration)
      }
      .store(in: &cancellables)
  }

  func removeContentPlayerObservers() {
    guard trackingContent else { return }
    trackingContent = false
    if let observer = playHeadObserver {
      contentPlayer.removeTimeObserver(observer)
      playHeadObserver = nil
    }
    cancellables.forEach { $0.cancel() }
    cancellables.removeAll()
  }

  override var prefersStatusBarHidden: Bool {
    return isStatusBarHidden
  }

  // MARK: - UI Handlers
  @IBAction func onPlayPauseClicked(_ sender: Any) {
    if isStreamPlaying {
      contentPlayer.pause()
    } else {
      contentPlayer.play()
    }
  }

  func updatePlayHeadState(isPlaying: Bool) {
    playHeadButton.setImage(isPlaying ? pauseBtnBG : playBtnBG, for: .normal)
  }

  @IBAction func progressBarValueChanged(_ sender: UISlider) {
    guard !isAdPlaying else {
      sender.value = Float(contentPlayer.currentTime().seconds)
      return
    }
    contentPlayer.seek(to: CMTime(seconds: Double(sender.value), preferredTimescale: 1000))
  }

  // [START snapback_example]
  @IBAction func progressBarTouchStarted(_ sender: UISlider) {
    guard !isAdPlaying else { return }
    currentlySeeking = true
    seekStartTime = contentPlayer.currentTime().seconds
  }

  // MARK: Snapback Logic
  @IBAction func progressBarTouchEnded(_ sender: UISlider) {
    guard !isAdPlaying else { return }
    if isFullScreen {
      startHideControlsTimer()
    }
    currentlySeeking = false
    seekEndTime = Float64(sender.value)

    guard let streamManager else { return }

    if let lastCuepoint = streamManager.previousCuepoint(forStreamTime: seekEndTime) {
      if !lastCuepoint.isPlayed, lastCuepoint.startTime > seekStartTime {
        logMessage(
          "Snapback to \(String(format: "%.2f", lastCuepoint.startTime)) from \(String(format: "%.2f", seekEndTime))"
        )
        snapbackMode = true
        contentPlayer.seek(
          to: CMTime(seconds: Double(sender.value), preferredTimescale: 1000))
      }
    }
  }
  // [END snapback_example]

  func updatePlayHead(with time: CMTime, duration: CMTime) {
    guard CMTIME_IS_VALID(time) else { return }
    let currentTime = time.seconds
    guard !currentTime.isNaN else { return }

    if !currentlySeeking {
      progressBar.value = Float(currentTime)
    }
    playHeadTimeText.text = formatTime(currentTime)
    updatePlayHeadDuration(with: duration)
  }

  func updatePlayHeadDuration(with duration: CMTime) {
    guard CMTIME_IS_VALID(duration) else { return }
    let durationValue = duration.seconds
    guard !durationValue.isNaN else { return }

    progressBar.maximumValue = Float(durationValue)
    durationTimeText.text = formatTime(durationValue)
  }

  // MARK: - Rotation Handling
  override func viewWillTransition(
    to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator
  ) {
    super.viewWillTransition(to: size, with: coordinator)
    coordinator.animate(alongsideTransition: nil) { (context) in
      guard let windowScene = self.view.window?.windowScene else { return }
      if windowScene.interfaceOrientation.isLandscape {
        self.viewDidEnterLandscape()
      } else {
        self.viewDidEnterPortrait()
      }
    }
  }

  func viewDidEnterLandscape() {
    isFullScreen = true
    let screenRect = UIScreen.main.bounds
    let fullScreenVideoFrame = CGRect(
      x: 0,
      y: 0,
      width: screenRect.width,
      height: screenRect.height)
    fullScreenControlsFrame = CGRect(
      x: 0,
      y: (screenRect.height - videoControls.frame.size.height),
      width: screenRect.width,
      height: videoControls.frame.size.height)
    isStatusBarHidden = true
    setNeedsStatusBarAppearanceUpdate()
    navigationController?.isNavigationBarHidden = true
    videoView.frame = fullScreenVideoFrame
    contentPlayerLayer.frame = fullScreenVideoFrame
    videoControls.frame = fullScreenControlsFrame
    videoControls.isHidden = true
  }

  func viewDidEnterPortrait() {
    isFullScreen = false
    isStatusBarHidden = false
    setNeedsStatusBarAppearanceUpdate()
    navigationController?.isNavigationBarHidden = false
    videoView.frame = portraitVideoViewFrame
    contentPlayerLayer.frame = portraitVideoViewBounds
    videoControls.frame = portraitControlsViewFrame
    videoControls.isHidden = false
    videoControls.alpha = 1
  }

  // MARK: - FullScreen Controls
  @objc func showFullScreenControls(_ recognizer: UITapGestureRecognizer?) {
    if isFullScreen {
      videoControls.isHidden = false
      videoControls.alpha = 0.9
      startHideControlsTimer()
    }
  }

  func startHideControlsTimer() {
    hideControlsWorkItem?.cancel()
    let workItem = DispatchWorkItem { [weak self] in
      self?.hideFullScreenControls()
    }
    hideControlsWorkItem = workItem
    DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: workItem)
  }

  func hideFullScreenControls() {
    if isFullScreen {
      if UIAccessibility.isReduceMotionEnabled {
        videoControls.alpha = 0.0
      } else {
        UIView.animate(withDuration: 0.5) {
          self.videoControls.alpha = 0.0
        }
      }
    }
  }

  // MARK: - Subtitles
  func showSubtitles() {
    guard let playerItem = contentPlayer.currentItem else { return }
    let asset = playerItem.asset
    Task {
      do {
        let legibleGroup = try await asset.loadMediaSelectionGroup(for: .legible)
        if let group = legibleGroup {
          // Example: Always select the first English subtitle track if available.
          // A real app would present a UI to let the user choose.
          let englishOptions = AVMediaSelectionGroup.mediaSelectionOptions(
            from: group.options, with: Locale(identifier: "en"))
          if let option = englishOptions.first {
            playerItem.select(option, in: group)
            logMessage("English subtitles selected.")
          } else {
            logMessage("No English subtitle track found.")
          }
        } else {
          logMessage("No subtitle tracks found.")
        }
      } catch {
        logMessage("Error loading subtitle media selection group: \(error)")
      }
    }
  }

  // MARK: - IMA Methods
  func requestStream() {
    guard let stream, let adsLoader else {
      logMessage("Error: Stream or AdsLoader not available.")
      return
    }

    let adDisplayContainer = IMAAdDisplayContainer(
      adContainer: videoView, viewController: self, companionSlots: nil)
    imaVideoDisplay = IMAAVPlayerVideoDisplay(avPlayer: contentPlayer)

    let request: IMAStreamRequest

    switch stream {
    case let liveStream as LiveStream:
      let liveRequest = IMALiveStreamRequest(
        assetKey: liveStream.assetKey, networkCode: liveStream.networkCode,
        adDisplayContainer: adDisplayContainer, videoDisplay: imaVideoDisplay, userContext: nil)
      liveRequest.apiKey = liveStream.apiKey
      request = liveRequest
      logMessage("Requesting Live Stream...")
    case let vodStream as VODStream:
      let vodRequest = IMAVODStreamRequest(
        contentSourceID: vodStream.cmsID, videoID: vodStream.videoID,
        networkCode: vodStream.networkCode, adDisplayContainer: adDisplayContainer,
        videoDisplay: imaVideoDisplay, userContext: nil)
      vodRequest.apiKey = vodStream.apiKey
      request = vodRequest
      logMessage("Requesting VOD Stream...")
    default:
      logMessage("Error: Unsupported stream type.")
      return
    }
    adsLoader.requestStream(with: request)
  }

  // MARK: - IMAAdsLoaderDelegate
  func adsLoader(_ loader: IMAAdsLoader, adsLoadedWith adsLoadedData: IMAAdsLoadedData) {
    logMessage("Stream created with ID: \(adsLoadedData.streamManager?.streamId ?? "N/A").")
    streamManager = adsLoadedData.streamManager
    streamManager?.delegate = self
    let adsRenderingSettings = IMAAdsRenderingSettings()
    adsRenderingSettings.uiElements = [
      NSNumber(value: IMAUiElementType.elements_COUNTDOWN.rawValue),
      NSNumber(value: IMAUiElementType.elements_AD_ATTRIBUTION.rawValue),
    ]
    streamManager?.initialize(with: adsRenderingSettings)
  }

  func adsLoader(_ loader: IMAAdsLoader, failedWith adErrorData: IMAAdLoadingErrorData) {
    logMessage(
      "AdsLoader error, code: \(adErrorData.adError.code.rawValue), message: \(adErrorData.adError.message ?? "nil")."
    )
    playFallBackContent()
  }

  // MARK: - IMAStreamManagerDelegate
  func streamManager(_ streamManager: IMAStreamManager, didReceive adEvent: IMAAdEvent) {
    logMessage("StreamManager event: \(adEvent.typeString).")
    switch adEvent.type {
    case .STARTED:
      isAdPlaying = true
      progressBar.isUserInteractionEnabled = false
      updatePlayHeadState(isPlaying: true)
      if let ad = adEvent.ad {
        let adPodInfo = ad.adPodInfo
        let bumperString = adPodInfo.isBumper ? "YES" : "NO"
        let adTitle = ad.adTitle
        let adDescription = ad.adDescription
        let contentType = ad.contentType

        let extendedAdPodInfo = """
          Showing ad \(adPodInfo.adPosition)/\(adPodInfo.totalAds), \
          bumper: \(bumperString), \
          title: \(adTitle), \
          description: \(adDescription), \
          contentType: \(contentType), \
          pod index: \(adPodInfo.podIndex), \
          time offset: \(String(format: "%.2f", adPodInfo.timeOffset)), \
          max duration: \(String(format: "%.2f", adPodInfo.maxDuration)).
          """
        logMessage(extendedAdPodInfo)
      }
    case .COMPLETE, .SKIPPED:
      isAdPlaying = false
      progressBar.isUserInteractionEnabled = true
      updatePlayHeadState(isPlaying: self.isContentPlaying)
    // [START snapback_case]
    case .AD_BREAK_ENDED:
      logMessage("Ad break ended")
      isAdPlaying = false
      progressBar.isUserInteractionEnabled = true
      if snapbackMode {
        snapbackMode = false
        if contentPlayer.currentTime().seconds < seekEndTime {
          contentPlayer.seek(to: CMTime(seconds: Double(seekEndTime), preferredTimescale: 1000))
        }
      } else if pendingBookmarkSeek, let time = bookmarkStreamTime {
        logMessage(String(format: "AD_BREAK_ENDED: Seeking to bookmark streamTime: %.2f", time))
        imaVideoDisplay.seekStream(toTime: time)
        pendingBookmarkSeek = false
        bookmarkStreamTime = nil
      }
      updatePlayHeadState(isPlaying: self.isContentPlaying)
    // [END snapback_case]
    case .AD_BREAK_STARTED:
      logMessage("Ad break started")
      isAdPlaying = true
      progressBar.isUserInteractionEnabled = false
      updatePlayHeadState(isPlaying: true)
    case .AD_PERIOD_STARTED:
      logMessage("Ad period started")
    case .AD_PERIOD_ENDED:
      logMessage("Ad period ended")
    // MARK: Bookmark Loading
    // [START load_bookmark_example]
    case .STREAM_LOADED:
      guard let stream else { return }
      addContentPlayerObservers()
      if let vodStream = stream as? VODStream, vodStream.bookmarkTime > 0 {
        bookmarkStreamTime = streamManager.streamTime(forContentTime: vodStream.bookmarkTime)
        if let time = bookmarkStreamTime {
          pendingBookmarkSeek = true
          logMessage(
            "STREAM_LOADED: Bookmark pending for contentTime: \(String(format: "%.2f", vodStream.bookmarkTime)) (streamTime: \(String(format: "%.2f", time)))"
          )
          vodStream.bookmarkTime = 0
        }
      }
      // [END load_bookmark_example]
      showSubtitles()
      contentPlayer.play()
      isStreamPlaying = true
      updatePlayHeadState(isPlaying: true)
    case .TAPPED:
      showFullScreenControls(nil)
    default:
      break
    }
  }

  func streamManager(_ streamManager: IMAStreamManager, didReceive adError: IMAAdError) {
    logMessage(
      "StreamManager error type: \(adError.type.rawValue), code: \(adError.code.rawValue), message: \(adError.message ?? "nil")."
    )
    isAdPlaying = false
    pendingBookmarkSeek = false
    bookmarkStreamTime = nil
    updatePlayHeadState(isPlaying: self.isContentPlaying)
    playFallBackContent()
  }

  func streamManager(
    _ streamManager: IMAStreamManager,
    adDidProgressToTime time: TimeInterval,
    adDuration: TimeInterval,
    adPosition: Int,
    totalAds: Int,
    adBreakDuration: TimeInterval,
    adPeriodDuration: TimeInterval
  ) {
    // Called frequently during ad playback. Can be used for custom UI.
    logMessage(
      "Ad progress: \(String(format: "%.2f", time))/\(String(format: "%.2f", adDuration))")
  }

  // MARK: - Utility Methods
  private func playFallBackContent() {
    logMessage("Playing fallback content.")
    if !trackingContent {
      addContentPlayerObservers()
    }
    if let contentURL = URL(
      string: "http://devimages.apple.com/iphone/samples/bipbop/bipbopall.m3u8")
    {
      let playerItem = AVPlayerItem(url: contentURL)
      contentPlayer.replaceCurrentItem(with: playerItem)
      contentPlayer.play()
      isStreamPlaying = true
      updatePlayHeadState(isPlaying: true)
    }
  }

  private func scrollConsoleToBottom() {
    guard !consoleView.text.isEmpty else { return }
    let bottom = NSRange(
      location: (consoleView.text as NSString).length - 1,
      length: 1)
    consoleView.scrollRangeToVisible(bottom)
  }

  func logMessage(_ log: String) {
    print(log)
    DispatchQueue.main.async {
      self.consoleView.text.append("\(log)\n")
      self.scrollConsoleToBottom()
    }
  }

  private func formatTime(_ time: TimeInterval) -> String {
    let minutes = Int(time) / 60
    let seconds = Int(time) % 60
    return String(format: "%d:%02d", minutes, seconds)
  }
}
