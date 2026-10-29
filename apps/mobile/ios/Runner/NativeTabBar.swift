import Flutter
import UIKit

final class NativeTabBarFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger

  init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
    super.init()
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }

  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
    NativeTabBar(frame: frame, id: viewId, arguments: args, messenger: messenger)
  }
}

/// Leave materials, symbol rendering, VoiceOver and Reduce Transparency to iOS.
/// The same UITabBar uses the system's current appearance, with no version-
/// specific glass drawing or third-party shaders.
final class NativeTabBar: NSObject, FlutterPlatformView, UITabBarDelegate {
  private let tabBar: UITabBar
  private let channel: FlutterMethodChannel

  init(frame: CGRect, id: Int64, arguments: Any?, messenger: FlutterBinaryMessenger) {
    tabBar = UITabBar(frame: frame)
    channel = FlutterMethodChannel(name: "playerszwz/navigation/\(id)", binaryMessenger: messenger)
    super.init()
    tabBar.overrideUserInterfaceStyle = .dark
    tabBar.tintColor = UIColor(red: 215 / 255, green: 1, blue: 0, alpha: 1)
    tabBar.isTranslucent = true
    let destinations = [
      ("Explore", "map", "map.fill"),
      ("Activity", "bolt", "bolt.fill"),
      ("Arenas", "building.2", "building.2.fill"),
      ("Profile", "person.crop.circle", "person.crop.circle.fill"),
    ]
    tabBar.items = destinations.enumerated().map { index, destination in
      let item = UITabBarItem(title: destination.0,
                             image: UIImage(systemName: destination.1),
                             selectedImage: UIImage(systemName: destination.2))
      item.tag = index
      item.accessibilityIdentifier = "playerszwz.tab.\(index)"
      return item
    }
    tabBar.delegate = self
    select((arguments as? [String: Any])?["selectedIndex"] as? Int ?? 0)
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "select", let index = call.arguments as? Int else {
        result(FlutterMethodNotImplemented)
        return
      }
      self?.select(index)
      result(nil)
    }
  }

  deinit {
    channel.setMethodCallHandler(nil)
  }

  private func select(_ index: Int) {
    guard let items = tabBar.items, items.indices.contains(index) else { return }
    tabBar.selectedItem = items[index]
  }

  func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
    channel.invokeMethod("selected", arguments: item.tag)
  }

  func view() -> UIView { tabBar }
}
