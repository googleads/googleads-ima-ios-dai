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

/// IMA iOS SDK - Secure Signals
/// Demonstrates setting an encoded secure signal string on your stream request.
class SecureSignalsSnippet: NSObject {

  func setSecureSignals(streamRequest: IMAStreamRequest) {
    // [START make_secure_signals_stream_request]
    let signals = IMASecureSignals(customData: "ENCODED_SIGNAL_STRING")
    streamRequest.secureSignals = signals
    // [END make_secure_signals_stream_request]
  }
}
