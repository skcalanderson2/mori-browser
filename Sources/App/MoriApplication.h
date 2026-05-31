// NSApplication subclass required by CEF on macOS.
//
// CEF needs to track whether AppKit is currently inside -sendEvent: so it can
// correctly pump its own work without re-entrancy issues. This is mandated by
// CEF (see include/cef_application_mac.h, CefAppProtocol).
#import <Cocoa/Cocoa.h>
#include "include/cef_application_mac.h"

@interface MoriApplication : NSApplication <CefAppProtocol>
@end
