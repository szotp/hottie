import Cocoa
import FlutterMacOS
import hottie

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController.init()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    HottiePlugin.instance.setRoot();

    super.awakeFromNib()
  }
}
