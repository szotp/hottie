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
    switch call.method {
    case "initialize":
        let args = call.arguments as! [String: Any]
        let handleRaw = args["handle"] as! Int64
        let handle = FlutterCallbackCache.lookupCallbackInformation(handleRaw)!
        let ok = engine.run(withEntrypoint: handle.callbackName, libraryURI: handle.callbackLibraryPath)
        result(ok)
    default:
        assertionFailure()
        result(nil)
    }
  }
}
