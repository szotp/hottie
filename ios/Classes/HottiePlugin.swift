import Flutter
import UIKit

#if DEBUG
public class HottiePlugin: NSObject, FlutterPlugin, SpawnHostApi {
    public static func register(with registrar: FlutterPluginRegistrar) {
        SpawnHostApiSetup.setUp(binaryMessenger: registrar.messenger(), api: instance)
    }
    
    public static let instance = HottiePlugin()

    let group = FlutterEngineGroup(name: "hottie", project: nil)
    
    var engine: FlutterEngine?
    
    func spawn(entryPoint: String, args: [String]) throws {
        engine?.destroyContext()
        engine = nil
        
        let options = FlutterEngineGroupOptions()
        options.entrypoint = entryPoint
        options.entrypointArgs = args
        engine = self.group.makeEngine(with: options)
    }
    
    func close() throws {
        engine = nil
    }
}
#else
public class HottiePlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {}
}
#endif
