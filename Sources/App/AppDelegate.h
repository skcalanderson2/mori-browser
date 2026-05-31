#import <Cocoa/Cocoa.h>

// Owns the main window and hosts the SwiftUI chrome. Also coordinates a clean
// CEF shutdown when the last window closes / the app quits.
@interface AppDelegate : NSObject <NSApplicationDelegate>
@end
