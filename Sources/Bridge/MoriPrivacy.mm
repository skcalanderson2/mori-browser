#import "MoriPrivacy.h"

#include "include/cef_cookie.h"
#include "include/cef_request_context.h"
#include "include/wrapper/cef_helpers.h"

// These are always invoked from the AppKit main thread, which is CEF's UI
// thread (the app runs CefRunMessageLoop() on main). The global cookie/cache
// APIs require the UI thread, so calling inline here is correct.

@implementation MoriPrivacy

+ (void)clearCookies {
  CEF_REQUIRE_UI_THREAD();
  CefRefPtr<CefCookieManager> mgr = CefCookieManager::GetGlobalManager(nullptr);
  if (mgr) {
    mgr->DeleteCookies(CefString(), CefString(), nullptr);
    mgr->FlushStore(nullptr);
  }
}

+ (void)clearCache {
  CEF_REQUIRE_UI_THREAD();
  CefRefPtr<CefRequestContext> ctx = CefRequestContext::GetGlobalContext();
  if (ctx) {
    ctx->ClearHttpCache(nullptr);
  }
}

+ (void)flushCookies {
  CEF_REQUIRE_UI_THREAD();
  CefRefPtr<CefCookieManager> mgr = CefCookieManager::GetGlobalManager(nullptr);
  if (mgr) {
    mgr->FlushStore(nullptr);
  }
}

@end
