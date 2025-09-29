// [START import_ima_sdk]
import GoogleInteractiveMediaAds
// [START_EXCLUDE]
import SwiftUI

enum Platform {
  case iOS
  case tvOS
}

class CustomUIDataModel: ObservableObject {
  @Published var currentTime: Float64 = 0
  var uiElements: [String: UIView] = [:]
  var refreshUiElements: Bool = false
  var reachedSkipOffset: Bool = false
  let platform: Platform
  @Published var fallbackImage: IMAUIFallbackImage? = nil

  init() {
    #if os(tvOS)
      platform = .tvOS
    #else
      platform = .iOS
    #endif
  }
}

public struct CustomUIView: View {

  private var customUI: IMACustomUI
  private var ad: IMAAd
  private var videoView: UIView
  @ObservedObject private var dataModel: CustomUIDataModel

  init(customUI: IMACustomUI, ad: IMAAd, videoView: UIView, dataModel: CustomUIDataModel) {
    self.customUI = customUI
    self.ad = ad
    self.videoView = videoView
    self.dataModel = dataModel
  }

  private var renderedUIElements: [String: AnyView] {
    let config = self.customUI.config
    var elements: [String: AnyView] = [:]
    if let fallbackImage = self.dataModel.fallbackImage {
      elements[fallbackImage.id] = AnyView(
        CustomUIFallbackImage(
          fallbackImage: fallbackImage,
          action: { event in
            self.dataModel.fallbackImage = nil
            self.dataModel.refreshUiElements = true
            if event != nil {
              self.customUI.uiElement(fallbackImage.id, didClickWith: event!)
            }
          }
        ))
      return elements
    }

    if let videoOverlay = config.videoOverlay {
      let overlay =
        UIButtonRepresentable(
          title: "",
          action: { event in
            self.customUI.uiElement(videoOverlay.id, didClickWith: event)
          },
          font: .systemFont(ofSize: 0),
          foregroundColor: .clear
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      elements[videoOverlay.id] = AnyView(overlay)
    }

    if let attribution = config.attribution {
      elements[attribution.id] = AnyView(
        Text(attribution.text)
          .font(.body)
          .foregroundColor(.yellow)
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
      )
    }

    if let callToAction = config.callToAction {
      elements[callToAction.id] = AnyView(
        CustomUIButton(
          title: callToAction.text,
          action: { event in
            self.customUI.uiElement(callToAction.id, didClickWith: event)
          }
        ))
    }

    if let skip = config.skip {
      if self.dataModel.currentTime < self.ad.skipTimeOffset {
        let timeToSkip = self.ad.skipTimeOffset - self.dataModel.currentTime
        let countdownText = skip.countdown.text.replacingOccurrences(
          of: "${TIME_TO_SKIP_SECS}",
          with: String(format: "%.0f", timeToSkip)
        )
        elements[skip.countdown.id] = AnyView(
          Text(countdownText)
            .font(.title)
            .foregroundColor(.orange)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing))
      } else {
        elements[skip.button.id] = AnyView(
          CustomUIButton(
            title: skip.button.text,
            action: { event in
              self.customUI.uiElement(skip.button.id, didClickWith: event)
            }
          ))
      }
    }

    for icon in config.icons {
      elements[icon.id] = AnyView(
        CustomUIIcon(
          icon: icon,
          action: { event in
            if event != nil {
              self.customUI.uiElement(icon.id, didClickWith: event!)
            }
            if dataModel.platform == .tvOS {
              if icon.fallbackImages.count > 0 {
                self.dataModel.fallbackImage = icon.fallbackImages[0]
                self.dataModel.refreshUiElements = true
              }
            } else {
              if let clickURL = icon.clickURL {
                UIApplication.shared.open(clickURL, options: [:], completionHandler: nil)
              }
            }
          }))
    }

    if let adTitle = config.adTitle {
      elements[adTitle.id] = AnyView(CustomUILink(link: adTitle, customUI: self.customUI))
    }

    if let authorName = config.authorName {
      elements[authorName.id] = AnyView(CustomUILink(link: authorName, customUI: self.customUI))
    }

    if let authorIcon = config.authorIcon {
      elements[authorIcon.id] = AnyView(
        CustomUIIcon(
          icon: authorIcon,
          action: { event in
            if event != nil {
              self.customUI.uiElement(authorIcon.id, didClickWith: event!)
            }
            if let clickURL = authorIcon.clickURL {
              UIApplication.shared.open(clickURL, options: [:], completionHandler: nil)
            }
          }))
    }

    return elements
  }

  public var body: some View {
    let elements = renderedUIElements
    ZStack {
      ForEach(Array(elements.keys), id: \.self) { key in
        elements[key]
      }
    }
    .onAppear {
      // Defer to next run loop to allow uiElements to be populated.
      DispatchQueue.main.async {
        self.dataModel.uiElements = elements.mapValues { UIHostingController(rootView: $0).view }
        setVisibleElements()
      }
    }
    .onChange(of: dataModel.refreshUiElements) {
      // Defer to next run loop to allow uiElements to be populated.
      DispatchQueue.main.async {
        self.dataModel.refreshUiElements = false
        self.dataModel.uiElements = elements.mapValues {
          UIHostingController(rootView: $0).view
        }
        setVisibleElements()
      }
    }
  }

  private func setVisibleElements() {
    var visibleUIElements: [String: UIView] = [:]
    for (id, view) in dataModel.uiElements {
      visibleUIElements[id] = view
    }
    self.customUI.visibleUIElements = visibleUIElements
  }

  public func onProgress() {
    if self.ad.skipTimeOffset > 0 && dataModel.currentTime > self.ad.skipTimeOffset
      && !dataModel.reachedSkipOffset
    {
      dataModel.reachedSkipOffset = true
      dataModel.refreshUiElements = true
    }
  }

  public func dispose() {
    dataModel.uiElements.removeAll()
  }
}
