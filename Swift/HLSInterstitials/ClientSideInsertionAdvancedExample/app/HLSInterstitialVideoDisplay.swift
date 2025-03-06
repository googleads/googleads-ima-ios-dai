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

/// HLSInterstitialVideoDisplay is a class that implements the IMAVideoDisplay protocol and
/// provides functionality for displaying HLS interstitial ads and tracking their metadata events.
///
/// This class is intended for use in a sample context, and does not include all the functionality
/// that may be required in a production implementation. For example, it does not handle audio ads
/// or background playback.
class HLSInterstitialVideoDisplay: NSObject,
  IMAVideoDisplay,
  AVPlayerItemMetadataOutputPushDelegate
{
  var volume: Float

  var currentMediaTime: TimeInterval

  var bufferedMediaTime: TimeInterval

  var totalMediaTime: TimeInterval

  var isPlaying: Bool

  public var delegate: (any IMAVideoDisplayDelegate)?

  private var started: Bool = false
  private var player: AVPlayer
  private var mainPlayerItem: AVPlayerItem?
  private var currentPlayerItem: AVPlayerItem?
  private var timeObserver: Any?
  private var metadataOutputManager: AVPlayerItemMetadataOutput?
  private var interstitialEventMonitor: AVPlayerInterstitialEventMonitor?

  /// Initializes the HLSInterstitialVideoDisplay with the given AVPlayer.
  ///
  /// - Parameter player: The AVPlayer instance used to play content and interstitial ads.
  init(avPlayer player: AVPlayer) {
    self.volume = 0
    self.currentMediaTime = 0
    self.bufferedMediaTime = 0
    self.totalMediaTime = 0
    self.isPlaying = false
    self.player = player
    super.init()

    // Create an AVPlayerInterstitialEventMonitor to track interstitial events.
    interstitialEventMonitor = AVPlayerInterstitialEventMonitor(primaryPlayer: player)
    // Add an observer to track the change between the main player and the interstitial player.
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleInterstitialEvent(_:)),
      name: AVPlayerInterstitialEventMonitor.currentEventDidChangeNotification,
      object: interstitialEventMonitor
    )

    // Add an observer to track when the either the main player or the interstitial player has
    // finished playing.
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(playerItemDidPlayToEndTime(_:)),
      name: AVPlayerItem.didPlayToEndTimeNotification,
      object: nil
    )

    // Add a metadata output manager to track metadata events.
    self.metadataOutputManager = AVPlayerItemMetadataOutput(identifiers: nil)
    self.metadataOutputManager!.setDelegate(self, queue: DispatchQueue.main)
  }

  /// Loads the content stream with the given URL and subtitles.
  ///
  /// - Parameters:
  ///   - streamURL: The URL of the stream to load.
  ///   - subtitles: An array of subtitles to display. (not implemented in this sample)
  func loadStream(_ streamURL: URL, withSubtitles subtitles: [[String: String]]) {
    self.mainPlayerItem = AVPlayerItem(url: streamURL)
    self.player.replaceCurrentItem(with: self.mainPlayerItem)
    self.currentPlayerItem = self.mainPlayerItem
    self.started = false
    self.totalMediaTime = 0
    self.isPlaying = false

    // Add observers to the player and main player item.
    self.addPlayerObservers(player: self.player)
    self.addItemObservers(playerItem: self.mainPlayerItem!)
  }

  /// Adds observers to the given AVPlayer.
  ///
  /// - Parameter player: The AVPlayer instance to add observers to.
  func addPlayerObservers(player: AVPlayer) {
    // Observe player status to identify when the player is ready to play.
    player.addObserver(
      self,
      forKeyPath: "status",
      options: [.old, .new],
      context: nil
    )
    // Observe player volume to identify when the volume changes.
    player.addObserver(
      self,
      forKeyPath: "volume",
      options: [.old, .new],
      context: nil
    )
    // Periodically update the current media time.
    // Uses milliseconds as the preferred timescale to ensure that the accuracy is higher than human
    // perception.
    let interval = CMTime(seconds: 200, preferredTimescale: 1000)
    self.timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) {
      [weak self] time in
      self?.playerTickOccurred()
    }
  }

  /// Adds observers to the given AVPlayerItem.
  ///
  /// - Parameter playerItem: The AVPlayerItem instance to add observers to.
  func addItemObservers(playerItem: AVPlayerItem) {
    // Observe player status to identify when the player is ready to play.
    playerItem.addObserver(
      self,
      forKeyPath: "status",
      options: [.old, .new],
      context: nil
    )
    // Observe player time ranges to identify the buffer status.
    playerItem.addObserver(
      self,
      forKeyPath: "loadedTimeRanges",
      options: [.old, .new],
      context: nil
    )
    // Observe player buffer status to identify when the buffer is empty or full.
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
    // Add the metadata output manager to the player item to track metadata events.
    playerItem.add(metadataOutputManager!)
  }

  /// Removes observers from the given AVPlayer.
  ///
  /// - Parameter player: The AVPlayer instance to stop observing.
  func removePlayerObservers(player: AVPlayer) {
    player.removeObserver(self, forKeyPath: "status", context: nil)
    player.removeObserver(self, forKeyPath: "volume", context: nil)
    player.removeTimeObserver(self.timeObserver as Any)
  }

  /// Removes observers from the given AVPlayerItem.
  ///
  /// - Parameter playerItem: The AVPlayerItem instance to stop observing.
  func removeItemObservers(playerItem: AVPlayerItem) {
    playerItem.removeObserver(self, forKeyPath: "status", context: nil)
    playerItem.removeObserver(self, forKeyPath: "loadedTimeRanges", context: nil)
    playerItem.removeObserver(self, forKeyPath: "playbackBufferEmpty", context: nil)
    playerItem.removeObserver(self, forKeyPath: "playbackBufferFull", context: nil)
    playerItem.remove(metadataOutputManager!)
  }

  /// Called when the player's periodic time observer is triggered.
  ///
  /// This method is called periodically to update the current media time and notify the delegate
  /// when the video starts playing.
  func playerTickOccurred() {
    // If the player is not ready to play, do nothing.
    if self.mainPlayerItem?.status != .readyToPlay {
      return
    }
    // Call the delegate on the first non-buffering time update, to indicate that the video has
    // started playing.
    if !self.started {
      // prevent calling this delegate multiple times
      self.started = true
      self.delegate?.videoDisplayDidStart(_: self)
    }
    // Update the current media time and call the associated delegate method.
    guard let currentMediaTime = self.currentPlayerItem?.currentTime().seconds else { return }
    self.delegate?.videoDisplay(
      _: self,
      didProgressWithMediaTime: currentMediaTime,
      totalTime: self.totalMediaTime)
  }

  /// Plays the video.
  func play() {
    self.player.play()
  }

  /// Pauses the video.
  func pause() {
    self.player.pause()
  }

  /// Resets the VideoDisplay class for use with another media stream.
  ///
  /// This method is not implemented in this sample.
  func reset() {
    // not implemented in this sample
  }

  /// Seeks the video to the given time.
  ///
  /// - Parameter time: The time to seek to.
  func seekStream(toTime time: TimeInterval) {
    let cmtime = CMTime(seconds: time, preferredTimescale: 1000)
    self.player.seek(to: cmtime)
  }

  /// Provides a callback for key path changes in all AVPlayer and AVPlayerItem instances.
  internal override func observeValue(
    forKeyPath keyPath: String?,
    of object: Any?,
    change: [NSKeyValueChangeKey: Any]?,
    context: UnsafeMutableRawPointer?
  ) {
    if let player = object as? AVPlayer {
      // AVPlayer events
      if keyPath == "status" {
        // Player status. If the player is ready to play, get the content duration from the current
        // player item.
        if player.status == .readyToPlay {
          guard let currentPlayerItem = player.currentItem else { return }
          let asset = currentPlayerItem.asset
          Task {
            let duration = try? await asset.load(.duration)
            self.totalMediaTime = duration?.seconds ?? 0
            // Unknown durations, such as ongoing live streams, are set to 0.
            if self.totalMediaTime.isNaN {
              self.totalMediaTime = 0
            }
            // when the player is ready to play, play the video
            player.play()
          }
        }
      } else if keyPath == "timeControlStatus" {
        // Player time control status. Use this to identify when the player starts or stops playing.
        if player.timeControlStatus == .playing {
          if self.isPlaying == false {
            self.isPlaying = true
            self.delegate?.videoDisplayDidResume(_: self)
          }
        } else if self.isPlaying == true {
          self.isPlaying = false
          self.delegate?.videoDisplayDidPause(_: self)
        }
      } else if keyPath == "volume" {
        self.delegate?.videoDisplay(
          _: self,
          volumeChangedTo: player.volume as NSNumber
        )
      }
    } else if let playerItem = object as? AVPlayerItem {
      // Player item events.
      if keyPath == "status" {
        // Player item status. If the player item is ready to play, call the delegate to indicate
        // that the video display has loaded. If the player item failed to load, call the delegate
        // to indicate that an error occurred.
        if playerItem.status == .readyToPlay {
          self.delegate?.videoDisplayDidLoad(_: self)
        } else if playerItem.status == .failed {
          self.delegate?.videoDisplay(
            _: self,
            didReceiveError: playerItem.error!)
        }
      } else if keyPath == "loadedTimeRanges" {
        // Player item loaded time ranges. Use this to identify the buffer's progression.
        let currentTime = playerItem.currentTime()
        for entry in playerItem.loadedTimeRanges {
          if let range = entry as? CMTimeRange {
            if range.containsTime(currentTime) || CMTimeCompare(currentTime, range.end) <= 0 {
              self.delegate?.videoDisplay!(
                _: self,
                didBufferToMediaTime: range.end.seconds)
            }
          }
        }
      } else if keyPath == "playbackBufferEmpty" {
        // Player item playback buffer empty. Use this to identify when the player item starts
        // buffering.
        if playerItem.isPlaybackBufferEmpty {
          self.delegate?.videoDisplayDidStartBuffering!(_: self)
        }
      } else if keyPath == "playbackBufferFull" {
        // Player item playback buffer full. Use this to identify when the player item stops
        // buffering.
        if playerItem.isPlaybackBufferFull {
          self.delegate?.videoDisplayIsPlaybackReady!(_: self)
        }
      }
    }
  }

  /// Called when any player item has finished playing.
  @objc func playerItemDidPlayToEndTime(_ notification: Notification) {
    if self.currentPlayerItem == self.mainPlayerItem {
      // Call the delegate only when the main player item has finished playing.
      self.delegate?.videoDisplayDidComplete(_: self)
    }
  }

  /// Called when the interstitial event monitor's current event changes.
  @objc private func handleInterstitialEvent(_ notification: Notification) {
    guard let monitor = interstitialEventMonitor, let currentEvent = monitor.currentEvent else {
      print("Video player returned to underlying content.")
      // Interstitial has ended
      self.removeItemObservers(playerItem: currentPlayerItem!)
      self.currentPlayerItem = self.mainPlayerItem
      // Add observers to the main player and main player item.
      self.addPlayerObservers(player: self.player)
      self.addItemObservers(playerItem: self.mainPlayerItem!)
      return
    }
    print("Interstitial Event started.")
    // Interstitial has started
    self.currentPlayerItem = monitor.interstitialPlayer.currentItem
    // Remove observers from the main player and main player item.
    self.removePlayerObservers(player: self.player)
    self.removeItemObservers(playerItem: self.mainPlayerItem!)
    // Add observers to the interstitial player and the interstitial player item.
    self.addPlayerObservers(player: monitor.interstitialPlayer)
    guard let currentItem = monitor.interstitialPlayer.currentItem else { return }
    self.addItemObservers(playerItem: currentItem)
  }

  // MARK: AVPlayerItemMetadataOutputPushDelegate
  /// Called when the metadata output manager has new metadata groups.
  ///
  /// This method is called when the metadata output manager has new metadata groups. It extracts
  /// the metadata values and calls the delegate to notify it of the new metadata.
  func metadataOutput(
    _ output: AVPlayerItemMetadataOutput,
    didOutputTimedMetadataGroups groups: [AVTimedMetadataGroup],
    from track: AVPlayerItemTrack?
  ) {
    Task {
      var metadata: [String: String] = [:]
      for group in groups {
        for item in group.items {
          guard let metadataValue = try await item.load(.stringValue) else { continue }
          guard var id = item.identifier?.rawValue else { continue }
          // The raw ID from AVPlayer has a prefix of "id3/" that needs to be removed.
          // The IMA SDK expects the ID to be the name of the ID3 metadata event, without the
          // prefix. For example, "id3/TXXX" becomes "TXXX".
          if id.hasPrefix("id3/") {
            id = String(id.dropFirst(4))
          }
          metadata[id] = metadataValue
        }
      }
      self.delegate?.videoDisplay(_: self, didReceiveTimedMetadata: metadata)
    }
  }
}
