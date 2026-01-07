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

class VODStream: Stream {
  var cmsID: String
  var videoID: String
  var networkCode: String
  var bookmarkTime: TimeInterval = 0

  init(name: String, cmsID: String, videoID: String, networkCode: String, apiKey: String? = nil) {
    self.cmsID = cmsID
    self.videoID = videoID
    self.networkCode = networkCode
    super.init(name: name, apiKey: apiKey)
  }
}
