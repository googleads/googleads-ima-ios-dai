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

class ViewController: UIViewController {

  /// Content URL.
  static let backupStreamURLString =
    "http://devimages.apple.com/iphone/samples/bipbop/bipbopall.m3u8"

  /// Play button.
  @IBOutlet private weak var playButton: UIButton!

  @IBOutlet private weak var videoView: UIView!
  /// Video player.
  private var videoPlayer: AVPlayer?

  override func viewDidLoad() {
    super.viewDidLoad()

    playButton.layer.zPosition = CGFloat(MAXFLOAT)

    // Load AVPlayer with path to our content.
    let contentURL = URL(string: ViewController.backupStreamURLString)!
    videoPlayer = AVPlayer(url: contentURL)

    // Create a player layer for the player.
    let playerLayer = AVPlayerLayer(player: videoPlayer)

    // Size, position, and display the AVPlayer.
    playerLayer.frame = videoView.layer.bounds
    videoView.layer.addSublayer(playerLayer)
  }

  @IBAction func onPlayButtonTouch(_ sender: Any) {
    videoPlayer.play()
    playButton.isHidden = true
  }
}
