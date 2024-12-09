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

class HLSInterstitialVideoDisplay: NSObject,
  IMAVideoDisplay,
  AVPlayerItemMetadataOutputPushDelegate
{

  var currentMediaTime: TimeInterval
  var totalMediaTime: TimeInterval
  var bufferedMediaTime: TimeInterval

  var isPlaying: Bool

  public var delegate: (any IMAVideoDisplayDelegate)?
  public var volume: Float

  private var isMainPlayerItem: Bool
  private var started: Bool = false
  private var player: AVPlayer?
  private var controller: AVPlayerViewController?
  private var mainPlayerItem: AVPlayerItem?
  private var currentPlayerItem: AVPlayerItem?
  private var metadataOutputManager: AVPlayerItemMetadataOutput?
  private var interstitialEventMonitor: AVPlayerInterstitialEventMonitor?

  init(avPlayer player: AVPlayer) {
    self.currentMediaTime = 0
    self.totalMediaTime = 0
    self.bufferedMediaTime = 0
    self.isPlaying = false
    self.isMainPlayerItem = true
    self.volume = player.volume
    super.init()
    self.player = player
    // add metadata handler
    interstitialEventMonitor = AVPlayerInterstitialEventMonitor(primaryPlayer: player)

    // add notification center observers
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleInterstitialEvent(_:)),
      name: AVPlayerInterstitialEventMonitor.currentEventDidChangeNotification,
      object: interstitialEventMonitor
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(playerItemDidPlayToEndTime(_:)),
      name: AVPlayerItem.didPlayToEndTimeNotification,
      object: nil
    )
  }

  func loadStream(_ streamURL: URL, withSubtitles subtitles: [[String: String]]) {
    let playerItem = AVPlayerItem(url: streamURL)
    self.player!.replaceCurrentItem(with: playerItem)
    self.mainPlayerItem = playerItem
    self.volume = self.player!.volume
    self.started = false
    self.currentMediaTime = 0
    self.totalMediaTime = 0
    self.bufferedMediaTime = 0
    self.isPlaying = false
    self.isMainPlayerItem = true
    self.addPlayerObservers(player: self.player!)
    self.addItemObservers(playerItem: playerItem)
  }

  func addPlayerObservers(player: AVPlayer) {
    // player observers
    player.addObserver(
      self,
      forKeyPath: "status",
      options: [.old, .new],
      context: nil
    )
    player.addObserver(
      self,
      forKeyPath: "currentItem",
      options: [.old, .new],
      context: nil
    )
    player.addObserver(
      self,
      forKeyPath: "volume",
      options: [.old, .new],
      context: nil
    )
    // player time observer
    let interval = CMTime(seconds: 0.2, preferredTimescale: 600)
    player.addPeriodicTimeObserver(forInterval: interval, queue: nil) { [weak self] time in
      guard let self = self else { return }
      self.currentMediaTime = time.seconds
      playerTickOccurred()
    }
  }

  func addItemObservers(playerItem: AVPlayerItem) {
    // player item observers
    playerItem.addObserver(
      self,
      forKeyPath: "status",
      options: [.old, .new],
      context: nil
    )
    playerItem.addObserver(
      self,
      forKeyPath: "loadedTimeRanges",
      options: [.old, .new],
      context: nil
    )
    playerItem.addObserver(
      self,
      forKeyPath: "playbackBufferEmpty",
      options: [.old, .new],
      context: nil
    )
    playerItem.addObserver(
      self,
      forKeyPath: "playbackBufferFull",
      options: [.old, .new],
      context: nil
    )

    self.metadataOutputManager = AVPlayerItemMetadataOutput(identifiers: nil)
    self.metadataOutputManager!.setDelegate(self, queue: DispatchQueue.main)
    playerItem.add(metadataOutputManager!)
  }

  func playerTickOccurred() {
    if self.mainPlayerItem!.status != .readyToPlay {
      return
    }
    if !self.started {
      self.started = true
      self.delegate?.videoDisplayDidStart(_: self)
    }
    self.currentMediaTime = self.currentPlayerItem!.currentTime().seconds
    self.delegate?.videoDisplay(
      _: self,
      didProgressWithMediaTime: self.currentMediaTime,
      totalTime: self.totalMediaTime)
  }

  func play() {
    self.player!.play()
    // todo: call delegate function
  }

  func pause() {
    self.player!.pause()
    //todo: call delegate function
  }

  func reset() {

  }

  func seekStream(toTime time: TimeInterval) {
    let cmtime = CMTime(seconds: time, preferredTimescale: 1000)
    self.player!.seek(to: cmtime)
  }

  internal override func observeValue(
    forKeyPath keyPath: String?,
    of object: Any?,
    change: [NSKeyValueChangeKey: Any]?,
    context: UnsafeMutableRawPointer?
  ) {
    if let player = object as? AVPlayer {
      // player events
      if keyPath == "status" {
        if player.status == .readyToPlay {
          // grab duration from current avplayer item
          self.currentPlayerItem = player.currentItem
          let asset = self.currentPlayerItem!.asset
          Task {
            let duration = try? await asset.load(.duration)
            self.totalMediaTime = duration?.seconds ?? 0
            if self.totalMediaTime.isNaN {
              self.totalMediaTime = 0
            }
            player.play()
          }
        }
      } else if keyPath == "timeControlStatus" {
        if player.timeControlStatus == .playing {
          if self.isPlaying == false {
            self.isPlaying = true
            self.delegate?.videoDisplayDidResume(_: self)
          }
        } else {
          if self.isPlaying == true {
            self.isPlaying = false
            self.delegate?.videoDisplayDidPause(_: self)
          }
        }
      } else if keyPath == "volume" {
        self.volume = player.volume
        self.delegate?.videoDisplay(
          _: self,
          volumeChangedTo: self.volume as NSNumber
        )
      }
    } else if let playerItem = object as? AVPlayerItem {
      // player item events
      if keyPath == "status" {
        if playerItem.status == .readyToPlay {
          self.delegate?.videoDisplayDidLoad(_: self)
        } else if playerItem.status == .failed {
          self.delegate?.videoDisplay(
            _: self,
            didReceiveError: playerItem.error!)
        }
      } else if keyPath == "loadedTimeRanges" {
        let currentTime = playerItem.currentTime()
        for entry in playerItem.loadedTimeRanges {
          if let range = entry as? CMTimeRange {
            if range.containsTime(currentTime) || CMTimeCompare(currentTime, range.end) <= 0 {
              self.bufferedMediaTime = range.end.seconds
              self.delegate?.videoDisplay!(
                _: self,
                didBufferToMediaTime: self.bufferedMediaTime)
            }
          }
        }
      } else if keyPath == "playbackBufferEmpty" {
        if playerItem.isPlaybackBufferEmpty {
          self.delegate?.videoDisplayDidStartBuffering!(_: self)
        }
      } else if keyPath == "playbackBufferFull" {
        if playerItem.isPlaybackBufferFull {
          self.delegate?.videoDisplayIsPlaybackReady!(_: self)
        }
      }
    }
  }

  @objc func playerItemDidPlayToEndTime(_ notification: Notification) {
    if self.isMainPlayerItem {
      self.delegate?.videoDisplayDidComplete(_: self)
    }
  }

  @objc private func handleInterstitialEvent(_ notification: Notification) {
    guard let monitor = interstitialEventMonitor, let currentEvent = monitor.currentEvent else {
      print("Video player returned to underlying content.")
      // Interstitial has ended
      self.currentPlayerItem = self.mainPlayerItem
      self.isMainPlayerItem = true
      return
    }
    print("Interstitial Event started.")
    // Interstitial has started
    self.currentPlayerItem = monitor.interstitialPlayer.currentItem
    self.isMainPlayerItem = false
    self.addPlayerObservers(player: monitor.interstitialPlayer)
    self.addItemObservers(playerItem: self.currentPlayerItem!)
  }

  // MARK: AVPlayerItemMetadataOutputPushDelegate
  func metadataOutput(
    _ output: AVPlayerItemMetadataOutput,
    didOutputTimedMetadataGroups groups: [AVTimedMetadataGroup],
    from track: AVPlayerItemTrack?
  ) {
    Task {
      var metadata: [String: String] = [:]
      for group in groups {
        for item in group.items {
          guard let metadataValue = try await item.load(.stringValue) else { return }
          var id = item.identifier?.rawValue
          if id!.hasPrefix("id3/") {
            id = String(id!.dropFirst(4))
          }
          metadata[id!] = metadataValue
        }
      }
      self.delegate!.videoDisplay(_: self, didReceiveTimedMetadata: metadata)
    }
  }
}
