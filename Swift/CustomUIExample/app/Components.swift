// [START import_ima_sdk]
import GoogleInteractiveMediaAds
// [START_EXCLUDE]
import SwiftUI

public struct CustomUIButton: View {

  let title: String
  let action: (UIEvent) -> Void

  init(title: String, action: @escaping (UIEvent) -> Void) {
    self.title = title
    self.action = action
  }

  public var body: some View {
    UIButtonRepresentable(
      title: title,
      action: { event in
        self.action(event)
      },
      font: .preferredFont(forTextStyle: .body),
      foregroundColor: .blue,
    )
  }
}

public struct CustomUILink: View {

  let link: IMAUILink
  let customUI: IMACustomUI

  init(link: IMAUILink, customUI: IMACustomUI) {
    self.link = link
    self.customUI = customUI
  }

  public var body: some View {
    CustomUIButton(
      title: self.link.text,
      action: { event in
        self.customUI.uiElement(self.link.id, didClickWith: event)
        UIApplication.shared.open(self.link.clickURL, options: [:], completionHandler: nil)
      }
    )
  }
}

public struct CustomUIIcon: View {

  let icon: IMAUIIcon
  let action: (UIEvent?) -> Void

  init(icon: IMAUIIcon, action: @escaping (UIEvent?) -> Void) {
    self.icon = icon
    self.action = action
  }

  public var body: some View {
    AnyView(
      HStack {
        Spacer()
        VStack {
          Spacer()
          ZStack {
            UIButtonRepresentable(
              title: "",
              action: self.action,
              font: .systemFont(ofSize: 0),
              foregroundColor: .clear,
            )
            AsyncImage(url: self.icon.image.url) { image in
              image.resizable().scaledToFit()
            } placeholder: {
              Color.clear
            }
            .allowsHitTesting(false)
          }
          .frame(width: CGFloat(self.icon.image.width), height: CGFloat(self.icon.image.height))
          .background(Color.blue)
        }
      })
  }
}

public struct CustomUIFallbackImage: View {

  let fallbackImage: IMAUIFallbackImage
  let action: (UIEvent?) -> Void

  init(fallbackImage: IMAUIFallbackImage, action: @escaping (UIEvent?) -> Void) {
    self.fallbackImage = fallbackImage
    self.action = action
  }

  public var body: some View {
    ZStack {
      Color.black.opacity(0.7).edgesIgnoringSafeArea(.all)
      VStack {
        HStack {
          Spacer()
          CustomUIButton(
            title: "x",
            action: self.action,
          )
        }
        Spacer()
        AsyncImage(url: self.fallbackImage.url) { image in
          image.resizable().scaledToFit()
        } placeholder: {
          Color.clear
        }
        Spacer()
      }
    }
  }
}

// A UIViewRepresentable to wrap a UIButton and capture the UIEvent on tap.
public struct UIButtonRepresentable: UIViewRepresentable {

  let title: String
  let action: (UIEvent) -> Void
  var font: UIFont = .preferredFont(forTextStyle: .body)
  var foregroundColor: UIColor = .systemBlue

  public func makeUIView(context: Context) -> UIButton {
    let button = UIButton(type: .system)
    button.setTitle(title, for: .normal)
    button.addTarget(
      context.coordinator,
      action: #selector(Coordinator.buttonTapped(_:forEvent:)),
      for: .primaryActionTriggered)
    return button
  }

  public func updateUIView(_ uiView: UIButton, context: Context) {
    uiView.setTitle(title, for: .normal)
    uiView.titleLabel?.font = font
    uiView.setTitleColor(foregroundColor, for: .normal)
  }

  public func makeCoordinator() -> Coordinator {
    Coordinator(action: action)
  }

  public class Coordinator: NSObject {
    let action: (UIEvent) -> Void

    init(action: @escaping (UIEvent) -> Void) {
      self.action = action
    }

    @objc func buttonTapped(_ sender: UIButton, forEvent event: UIEvent) {
      action(event)
    }
  }
}
