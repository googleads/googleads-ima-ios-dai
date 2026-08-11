// [START import_ima_sdk]
import GoogleInteractiveMediaAds
// [START_EXCLUDE]
import SwiftUI

public struct CustomUILink: View {

  let link: IMAUILink
  let customUI: IMACustomUI

  init(link: IMAUILink, customUI: IMACustomUI) {
    self.link = link
    self.customUI = customUI
  }

  public var body: some View {
    Button(
      action: {
        self.customUI.uiElement(self.link.id, didClickWith: nil)
        UIApplication.shared.open(self.link.clickURL, options: [:], completionHandler: nil)
      },
      label: {
        Text(self.link.text)
      })
  }
}

public struct CustomUIIcon: View {

  let icon: IMAUIIcon
  let action: () -> Void

  init(icon: IMAUIIcon, action: @escaping () -> Void) {
    self.icon = icon
    self.action = action
  }

  public var body: some View {
    HStack {
      Spacer()
      VStack {
        Spacer()
        ZStack {
          Button(
            action: {
              self.action()
            },
          ) {
            AsyncImage(url: self.icon.image.url) { image in
              image.resizable().scaledToFit()
            } placeholder: {
              Color.clear
            }
            .allowsHitTesting(false)
          }
        }
        .frame(width: CGFloat(self.icon.image.width), height: CGFloat(self.icon.image.height))
        .background(Color.blue)
      }
    }
  }
}

public struct CustomUIFallbackImage: View {

  let fallbackImage: IMAUIFallbackImage
  let action: () -> Void

  init(fallbackImage: IMAUIFallbackImage, action: @escaping () -> Void) {
    self.fallbackImage = fallbackImage
    self.action = action
  }

  public var body: some View {
    ZStack {
      Color.black.opacity(0.7).edgesIgnoringSafeArea(.all)
      AsyncImage(url: self.fallbackImage.url) { image in
        image.resizable().scaledToFill()
      } placeholder: {
        Color.clear
      }
      .edgesIgnoringSafeArea(.all)
      VStack {
        HStack {
          Spacer()
          Button(
            action: {
              self.action()
            },
            label: {
              Text("x")
            })
        }
        Spacer()
      }
    }
  }
}
