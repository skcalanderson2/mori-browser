// Bridge between the extension scheme handler (CefAppImpl.mm) and the chrome.*
// runtime builder that lives in BrowserClient.mm. Both compile into the Mori
// app target, so the scheme handler can inject the full extension runtime into
// a page's HTML at serve time — guaranteeing it runs before the page's own
// bundled scripts, rather than racing them via an async OnLoadStart IPC.
#pragma once

#import <Foundation/Foundation.h>

// Full, wrapped chrome.* runtime shim JS for an enabled extension page, or nil
// if the id doesn't resolve to an enabled extension. Defined in BrowserClient.mm.
NSString* MoriExtensionPageRuntimeJS(NSString* extensionID);
