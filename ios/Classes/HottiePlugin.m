#import "HottiePlugin.h"
#if __has_include(<hottie/hottie-Swift.h>)
#import <hottie/hottie-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "hottie-Swift.h"
#endif

@implementation HottiePlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftHottiePlugin registerWithRegistrar:registrar];
}
@end
