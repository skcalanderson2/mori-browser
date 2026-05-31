#import "MoriApplication.h"

// Generated from the Swift @objc interface (SWIFT_OBJC_INTERFACE_HEADER_NAME).
#import "Mori-Swift.h"

@implementation MoriApplication {
  BOOL _handlingSendEvent;
}

- (BOOL)isHandlingSendEvent {
  return _handlingSendEvent;
}

- (void)setHandlingSendEvent:(BOOL)handlingSendEvent {
  _handlingSendEvent = handlingSendEvent;
}

- (void)sendEvent:(NSEvent*)event {
  if (event.type == NSEventTypeKeyDown) {
    NSEventModifierFlags m =
        event.modifierFlags & NSEventModifierFlagDeviceIndependentFlagsMask;
    BOOL candidate =
        (m & (NSEventModifierFlagCommand | NSEventModifierFlagControl)) != 0;
    BOOL handled = [MoriRoot handleShortcutEvent:event];
    if (candidate) {
      NSLog(@"KEYDBG sendEvent code=%d chars=%@ mods=0x%lx handled=%d "
            @"keyWin=%@ firstResp=%@",
            (int)event.keyCode, event.charactersIgnoringModifiers,
            (unsigned long)m, handled, NSApp.keyWindow.className,
            NSApp.keyWindow.firstResponder.className);
    }
    if (handled) return;
  }

  CefScopedSendingEvent sendingEventScoper;
  [super sendEvent:event];
}

// A browser is "active" for the purposes of the standard Cmd-key shortcuts.
// Terminate cleanly when the user chooses Quit.
- (void)terminate:(id)sender {
  [super terminate:sender];
}

@end
