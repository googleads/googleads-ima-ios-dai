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

import Foundation

enum StreamType {
  case live
  case vod
}

class Video {
  let title: String
  let streamType: StreamType
  let assetKey: String?
  let contentSourceID: String?
  let videoID: String?
  let networkCode: String
  let apiKey: String?
  var savedTime: TimeInterval = 0

  init(title: String, assetKey: String, networkCode: String, apiKey: String?) {
    self.title = title
    self.streamType = .live
    self.assetKey = assetKey
    self.contentSourceID = nil
    self.videoID = nil
    self.networkCode = networkCode
    self.apiKey = apiKey
  }

  init(
    title: String, contentSourceID: String, videoID: String, networkCode: String, apiKey: String?
  ) {
    self.title = title
    self.streamType = .vod
    self.assetKey = nil
    self.contentSourceID = contentSourceID
    self.videoID = videoID
    self.networkCode = networkCode
    self.apiKey = apiKey
  }
}
