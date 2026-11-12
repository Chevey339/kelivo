#include "../restricted_preview_policy.h"

#include <cstdlib>
#include <iostream>
#include <vector>

using Policy = RestrictedPreviewPolicy;
using Step = Policy::Step;
using Resource = Policy::Resource;

void Require(bool passed, const char* condition, int line) {
  if (!passed) {
    std::cerr << "line " << line << ": " << condition << '\n';
    std::exit(EXIT_FAILURE);
  }
}
#define CHECK(condition) Require((condition), #condition, __LINE__)

int main() {
  const std::vector order{Step::Settings, Step::Navigation, Step::Resources,
                          Step::Capabilities};
  // Every installer failure must synchronously close without trying any later
  // stage. No load, method reinitialization, or late callback can reopen it.
  for (size_t fail = 0; fail < order.size(); ++fail) {
    Policy policy;
    std::vector<Step> seen;
    int closed = 0;
    const auto close = [&] { ++closed; };
    CHECK(!policy.Initialize([&](Step step) {
      seen.push_back(step);
      CHECK(!policy.AllowMainNavigation(L"about:blank"));
      CHECK(!policy.AllowResource(L"https://example.test", Resource::Document));
      return step != order[fail];
    }, close));
    CHECK(seen == std::vector<Step>(order.begin(), order.begin() + fail + 1));
    CHECK(closed == 1);
    CHECK(policy.closed());
    CHECK(!policy.LoadDocument([]() -> bool { std::abort(); }, close));
    CHECK(!policy.Initialize([](Step) -> bool { std::abort(); }, close));
    policy.Close(close);
    CHECK(closed == 1);
  }

  Policy policy;
  std::vector<Step> seen;
  int closed = 0;
  const auto close = [&] { ++closed; };
  CHECK(!policy.LoadDocument([]() -> bool { std::abort(); }, close));
  CHECK(policy.Initialize([&](Step step) { seen.push_back(step); return true; }, close));
  CHECK(seen == order);
  CHECK(closed == 0);
  CHECK(!policy.AllowMainNavigation(L"about:blank"));
  CHECK(!policy.AllowFrameNavigation(L"about:srcdoc"));
  CHECK(!policy.Initialize([](Step) -> bool { std::abort(); }, close));
  int navigations = 0;
  CHECK(policy.LoadDocument([&] {
    // This stands in for NavigateToString. Resource filtering and every other
    // installer must have returned successfully before navigation is invoked.
    CHECK(seen == order);
    ++navigations;
    CHECK(policy.AllowMainNavigation(L"about:blank"));
    return true;
  }, close));
  CHECK(navigations == 1);
  CHECK(!policy.AllowMainNavigation(L"about:blank"));
  CHECK(!policy.LoadDocument([]() -> bool { std::abort(); }, close));
  CHECK(policy.AllowFrameNavigation(L"about:srcdoc"));
  CHECK(policy.AllowFrameNavigation(L"about:blank"));
  CHECK(policy.AllowResource(L"about:srcdoc", Resource::Document));
  CHECK(policy.AllowResource(L"data:image/png;base64,AA==", Resource::Image));
  CHECK(policy.AllowResource(L"data:font/woff2;base64,AA==", Resource::Font));

  for (auto uri : {L"https://example.test", L"http://localhost:8080/a",
                  L"http://127.0.0.1/a", L"file:///C:/private", L"\\\\server\\share",
                  L"mailto:hello@example.test", L"ms-settings:privacy", L"about:config",
                  L"about:blank#second", L"data:text/html,hello", L"blob:null/example"}) {
    CHECK(!policy.AllowMainNavigation(uri));
    CHECK(!policy.AllowFrameNavigation(uri));
    CHECK(!policy.AllowResource(uri, Resource::Document));
    CHECK(!policy.AllowResource(uri, Resource::Other));
    if (!std::wstring_view(uri).starts_with(L"data:")) {
      CHECK(!policy.AllowResource(uri, Resource::Image));
      CHECK(!policy.AllowResource(uri, Resource::Font));
    }
  }
  for (auto method : {"loadStringContent", "setSize", "setCursorPos", "setPointerUpdate",
                      "setPointerButton", "setScrollDelta", "setBackgroundColor",
                      "setZoomFactor", "setFpsLimit", "suspend", "resume"}) {
    CHECK(Policy::AllowMethod(method));
  }
  for (auto method : {"initialize", "loadUrl", "reload", "goBack", "goForward", "stop",
                      "executeScript", "postWebMessage", "openDevTools", "clearCookies",
                      "clearCache", "setCacheDisabled", "setPopupWindowPolicy", "setUserAgent",
                      "setVirtualHostNameMapping", "clearVirtualHostNameMapping",
                      "addScriptToExecuteOnDocumentCreated", "removeScriptToExecuteOnDocumentCreated"}) {
    CHECK(!Policy::AllowMethod(method));
  }
  policy.Close(close);
  policy.Close(close);
  CHECK(closed == 1);
  CHECK(!policy.AllowMainNavigation(L"about:blank"));
  CHECK(!policy.AllowFrameNavigation(L"about:srcdoc"));
  CHECK(!policy.AllowResource(L"data:image/png,a", Resource::Image));

  Policy failed_load;
  CHECK(failed_load.Initialize([](Step) { return true; }, close));
  CHECK(!failed_load.LoadDocument([] { return false; }, close));
  CHECK(failed_load.closed());
  CHECK(closed == 2);
  failed_load.Close(close);
  CHECK(closed == 2);

  Policy closed_before_init;
  closed_before_init.Close(close);
  CHECK(!closed_before_init.Initialize([](Step) -> bool { std::abort(); }, close));
  CHECK(closed == 3);
  std::cout << "Restricted preview policy: initialization order, all failure boundaries, "
               "synchronous navigation/resource decisions, immutable method restrictions "
               "and idempotent Close passed.\n";
}
