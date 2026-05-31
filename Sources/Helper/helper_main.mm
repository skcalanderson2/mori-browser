// Mori Browser — CEF helper (sub-process) entry point.
//
// Every Chromium sub-process (renderer, GPU, utility, …) re-launches this
// helper executable. It must load the CEF framework dynamically and hand off
// to CefExecuteProcess, which never returns for sub-processes.

#include "include/cef_app.h"
#include "include/wrapper/cef_library_loader.h"

#include "../Shared/MoriSchemes.h"

namespace {

class HelperApp : public CefApp {
 public:
  void OnRegisterCustomSchemes(
      CefRawPtr<CefSchemeRegistrar> registrar) override {
    mori::RegisterCustomSchemes(registrar);
  }

 private:
  IMPLEMENT_REFCOUNTING(HelperApp);
};

}  // namespace

int main(int argc, char* argv[]) {
  // Load the CEF framework library at runtime instead of linking directly so
  // the helper bundles stay tiny and share the single embedded framework.
  CefScopedLibraryLoader library_loader;
  if (!library_loader.LoadInHelper()) {
    return 1;
  }

  CefMainArgs main_args(argc, argv);

  // Execute the secondary process with the same custom scheme registration as
  // the browser process, so extension pages/resources parse consistently.
  CefRefPtr<HelperApp> app(new HelperApp);
  return CefExecuteProcess(main_args, app.get(), nullptr);
}
