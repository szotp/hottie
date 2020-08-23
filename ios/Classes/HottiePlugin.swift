import Flutter
import UIKit


public class HottiePlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "com.szotp.Hottie", binaryMessenger: registrar.messenger())
    let instance = HottiePlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

   lazy var engine = FlutterEngine(name: "hottie", project: nil, allowHeadlessExecution: true)

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let url = URL(fileURLWithPath: #file).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    
    switch call.method {
    case "initialize":
        let ok = engine.run(withEntrypoint: "hottie")
        result([
            "ok": ok,
            "root": url.path,
        ])
    default:
        assertionFailure()
        result(nil)
    }
  }
}
