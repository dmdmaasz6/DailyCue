import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    OnnxInferencePlugin.register(with: self.registrar(forPlugin: "OnnxInferencePlugin")!)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
