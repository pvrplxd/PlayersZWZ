import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var nativeSheets: NativeSheets?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "PlayersNavigation") {
      registrar.register(NativeTabBarFactory(messenger: registrar.messenger()),
                         withId: "playerszwz/native-tab-bar")
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "PlayersGlass") {
      registrar.register(GlassButtonFactory(messenger: registrar.messenger()),
                         withId: "playerszwz/glass-button")
      registrar.register(GlassSliderFactory(messenger: registrar.messenger()),
                         withId: "playerszwz/glass-slider")
      registrar.register(GlassSegmentedFactory(messenger: registrar.messenger()),
                         withId: "playerszwz/segmented")
      nativeSheets = NativeSheets(messenger: registrar.messenger())
    }
  }
}
