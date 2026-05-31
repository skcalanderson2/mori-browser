// CefApp for the browser process. Configures command-line switches and
// performs work after the global CEF context is initialized.
#pragma once

#include "include/cef_app.h"

class CefAppImpl : public CefApp, public CefBrowserProcessHandler {
 public:
  CefAppImpl();

  // CefApp
  CefRefPtr<CefBrowserProcessHandler> GetBrowserProcessHandler() override {
    return this;
  }
  void OnBeforeCommandLineProcessing(
      const CefString& process_type,
      CefRefPtr<CefCommandLine> command_line) override;
  void OnRegisterCustomSchemes(
      CefRawPtr<CefSchemeRegistrar> registrar) override;

  // CefBrowserProcessHandler
  void OnContextInitialized() override;

 private:
  IMPLEMENT_REFCOUNTING(CefAppImpl);
};
