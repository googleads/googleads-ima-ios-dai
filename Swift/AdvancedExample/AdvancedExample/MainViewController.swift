// Copyright 2025 Google LLC. All rights reserved.
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

import GoogleInteractiveMediaAds
import UIKit

class MainViewController: UIViewController,
  UITableViewDataSource,
  UITableViewDelegate,
  VideoViewControllerDelegate
{

  @IBOutlet weak var tableView: UITableView!

  private var streams: [Stream] = []
  private var adsLoader: IMAAdsLoader?

  // MARK: - Lifecycle
  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .white
    initStreams()
    adsLoader = IMAAdsLoader(settings: nil)
  }

  private func initStreams() {
    streams = [
      LiveStream(
        name: "Live stream", assetKey: "c-rArva4ShKVIAkNfy6HUQ", networkCode: "21775744923"),
      VODStream(
        name: "VOD Stream", cmsID: "2548831", videoID: "tears-of-steel", networkCode: "21775744923"),
    ]
  }

  // MARK: - UITableViewDataSource
  func numberOfSections(in tableView: UITableView) -> Int { return 1 }

  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return streams.count
  }

  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
    let selectedStream = streams[indexPath.row]
    cell.textLabel?.text = selectedStream.name
    return cell
  }

  // MARK: - Navigation
  override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    if segue.identifier == "showVideo" {
      if let indexPath = tableView.indexPathForSelectedRow {
        let selectedStream = streams[indexPath.row]
        if let destVC = segue.destination as? VideoViewController {
          destVC.delegate = self
          destVC.stream = selectedStream
          destVC.adsLoader = adsLoader
        }
      }
    }
  }

  // MARK: - VideoViewControllerDelegate
  func videoViewController(
    _ viewController: VideoViewController, didReportBookmarkedTime bookmarkTime: TimeInterval,
    for stream: Stream
  ) {
    if let vodStream = stream as? VODStream {
      vodStream.bookmarkTime = bookmarkTime
      print("Saved time for \(vodStream.name): \(bookmarkTime)")
    }
  }
}
