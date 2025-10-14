import GoogleInteractiveMediaAds
import SwiftUI

class CustomUIDataModel: ObservableObject {
  // Tracking the current time of the ad.
  @Published var currentTime: TimeInterval = 0
}

/// A view that represents the custom UI for an ad.
public struct CustomUIView: View {

  private var customUI: IMACustomUI
  private var ad: IMAAd
  private var videoView: UIView
  /// Used to determine if the skip button should be shown or if the skip countdown should be shown.
  @State var didReachSkipOffset: Bool = false
  /// Reference to the currently visible UI elements.
  /// Used to notify the SDK when the UI elements are shown or hidden.
  @State var visibleUIElements: Set<String> = []
  /// The fallback image to show when an icon is clicked.
  /// Used only on tvOS in lieu of a browser window.
  @State var fallbackImage: IMAUIFallbackImage? = nil
  /// The data model for the custom UI view.
  @ObservedObject private var dataModel: CustomUIDataModel

  /// - Parameters:
  ///   - customUI: Provider for SDK interactions.
  ///   - ad: The ad object for the custom UI view.
  ///   - videoView: The view for the video player.
  ///   - dataModel: The data model for the custom UI view.
  init(customUI: IMACustomUI, ad: IMAAd, videoView: UIView, dataModel: CustomUIDataModel) {
    self.customUI = customUI
    self.ad = ad
    self.videoView = videoView
    self.dataModel = dataModel
  }

  public var body: some View {
    let config = self.customUI.config
    if let fallbackImage = self.fallbackImage {
      CustomUIFallbackImage(
        fallbackImage: fallbackImage,
        action: {
          self.fallbackImage = nil
          self.customUI.uiElement(fallbackImage.id, didClickWith: nil)
        }
      )
      .onAppear {
        self.insertVisibleElement(fallbackImage.id)
      }
      .onDisappear {
        self.removeVisibleElement(fallbackImage.id)
      }
    } else {
      if let videoOverlay = config.videoOverlay {
        Button(
          action: {
            self.customUI.uiElement(videoOverlay.id, didClickWith: nil)
          }
        ) {
          Rectangle().opacity(0.0)
        }
        .foregroundColor(.clear)
        .font(.system(size: 0))
        .onAppear {
          self.insertVisibleElement(videoOverlay.id)
        }
        .onDisappear {
          self.removeVisibleElement(videoOverlay.id)
        }
      }
    }

    if let attribution = config.attribution {
      Text(attribution.text)
        .font(.body)
        .foregroundColor(.yellow)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
          self.insertVisibleElement(attribution.id)
        }
        .onDisappear {
          self.removeVisibleElement(attribution.id)
        }
    }

    if let callToAction = config.callToAction {
      Button(
        action: {
          self.customUI.uiElement(callToAction.id, didClickWith: nil)
        }
      ) {
        Text(callToAction.text)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(Color.clear)
      .onAppear {
        self.insertVisibleElement(callToAction.id)
      }
      .onDisappear {
        self.removeVisibleElement(callToAction.id)
      }
    }

    if let skip = config.skip {
      if self.dataModel.currentTime < self.ad.skipTimeOffset {
        let timeToSkip = self.ad.skipTimeOffset - self.dataModel.currentTime
        let countdownText = skip.countdown.text.replacingOccurrences(
          of: "${TIME_TO_SKIP_SECS}",
          with: String(format: "%.0f", timeToSkip)
        )

        Text(countdownText)
          .font(.title)
          .foregroundColor(.orange)
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
          .onAppear {
            self.insertVisibleElement(skip.button.id)
          }
          .onDisappear {
            self.removeVisibleElement(skip.button.id)
          }
      } else {
        Button(
          action: {
            self.customUI.uiElement(skip.button.id, didClickWith: nil)
          }
        ) {
          Text(skip.button.text)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        .onAppear {
          self.insertVisibleElement(skip.button.id)
        }
        .onDisappear {
          self.removeVisibleElement(skip.button.id)
        }
      }
    }

    ForEach(config.icons, id: \.id) { icon in
      CustomUIIcon(
        icon: icon,
        action: {
          self.customUI.uiElement(icon.id, didClickWith: nil)
          #if os(tvOS)
            if icon.fallbackImages.count > 0 {
              self.fallbackImage = self.fallbackImageThatFitsInSize(
                self.videoView.frame.size, fallbackImages: icon.fallbackImages)
            }
          #else
            if let clickURL = icon.clickURL {
              UIApplication.shared.open(clickURL, options: [:], completionHandler: nil)
            }
          #endif
        }
      )
      .onAppear {
        self.insertVisibleElement(icon.id)
      }
      .onDisappear {
        self.removeVisibleElement(icon.id)
      }
    }

    if let adTitle = config.adTitle {
      CustomUILink(link: adTitle, customUI: self.customUI)
        .onAppear {
          self.insertVisibleElement(adTitle.id)
        }
        .onDisappear {
          self.removeVisibleElement(adTitle.id)
        }
    }

    if let authorName = config.authorName {
      CustomUILink(link: authorName, customUI: self.customUI)
        .onAppear {
          self.insertVisibleElement(authorName.id)
        }
        .onDisappear {
          self.removeVisibleElement(authorName.id)
        }
    }

    if let authorIcon = config.authorIcon {
      CustomUIIcon(
        icon: authorIcon,
        action: {
          self.customUI.uiElement(authorIcon.id, didClickWith: nil)
          if let clickURL = authorIcon.clickURL {
            UIApplication.shared.open(clickURL, options: [:], completionHandler: nil)
          }
        }
      )
      .onAppear {
        self.insertVisibleElement(authorIcon.id)
      }
      .onDisappear {
        self.removeVisibleElement(authorIcon.id)
      }
    }
  }

  private func insertVisibleElement(_ id: String) {
    self.visibleUIElements.insert(id)
    self.setVisibleElements()
  }

  private func removeVisibleElement(_ id: String) {
    self.visibleUIElements.remove(id)
    self.setVisibleElements()
  }

  private func setVisibleElements() {
    self.customUI.visibleUIElements = Dictionary(
      uniqueKeysWithValues: self.visibleUIElements.map { ($0, [NSNull()]) })
  }

  /// Called when the ad progress is updated.
  public func onProgress() {
    if self.ad.skipTimeOffset > 0 && dataModel.currentTime > self.ad.skipTimeOffset
      && !self.didReachSkipOffset
    {
      self.didReachSkipOffset = true
    }
  }

  private func fallbackImageThatFitsInSize(_ size: CGSize, fallbackImages: [IMAUIFallbackImage])
    -> IMAUIFallbackImage?
  {
    let aspectRatio = size.width / size.height
    // Choose the image that needs to be scaled the least to fit.
    var leastScaleDelta = CGFloat.greatestFiniteMagnitude
    var bestFallbackImage: IMAUIFallbackImage? = nil
    for fallbackImage in fallbackImages {
      var scale: CGFloat
      if CGFloat(fallbackImage.width) > CGFloat(fallbackImage.height) * aspectRatio {
        scale = size.width / CGFloat(fallbackImage.width)
      } else {
        scale = size.height / CGFloat(fallbackImage.height)
      }
      let scaleDelta = abs(scale - 1)
      if scaleDelta < leastScaleDelta {
        leastScaleDelta = scaleDelta
        bestFallbackImage = fallbackImage
      }
    }
    return bestFallbackImage
  }
}
