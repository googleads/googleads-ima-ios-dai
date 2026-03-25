// Copyright 2026 Google LLC. All rights reserved.
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
import GoogleInteractiveMediaAds
import UIKit

// Example function to demonstrate adding Publisher Provided Signals to an existing stream request
func addPublisherProvidedSignals(to streamRequest: IMAStreamRequest) {
  // [START pps]
  let userSignals = """
    {
       "PublisherProvidedTaxonomySignals": [
        {
          "taxonomy": "IAB_AUDIENCE_1_1",
          "values": [
            "6",
            "284"
          ]
          // '6' = 'Demographic | Age Range | 30-34'
          // '284' = 'Interest | Business and Finance |  Mergers and Acquisitions'
        },
        {
          "taxonomy": "IAB_CONTENT_2_2",
          "values": ["49", "138"]
          // '49' = 'Books and Literature | Poetry'
          // '138' = 'Education | College Education | College Planning'
        }
      ],
      "PublisherProvidedStructuredSignals": [
        {
            "type": "audio_feed",
            "single_value": "af_1"
        },
        {
            "type": "delivery",
            "values": ["cd_1", "cd_3"]
        }
      ]
    }
    """
  // [END pps]
  // [START pps_stream_request]
  func encodeSignals(jsonString: String) -> String? {
    guard let data = jsonString.data(using: .utf8) else {
      print("Error: Could not convert JSON string to data")
      return nil
    }

    let base64Signals = data.base64EncodedString()
    var encodedSignals = base64Signals.replacingOccurrences(of: "+", with: "%2B")
    encodedSignals = encodedSignals.replacingOccurrences(of: "/", with: "%2F")
    encodedSignals = encodedSignals.replacingOccurrences(of: "=", with: "%3D")
    return encodedSignals
  }

  if let encodedSignals = encodeSignals(jsonString: userSignals) {
    if streamRequest.adTagParameters != nil {
      streamRequest.adTagParameters!["ppsj"] = encodedSignals
    } else {
      streamRequest.adTagParameters = ["ppsj": encodedSignals]
    }
    print("Successfully added encoded PPSJ to adTagParameters")
  } else {
    print("Error encoding user signals")
  }
  // [END pps_stream_request]
}
