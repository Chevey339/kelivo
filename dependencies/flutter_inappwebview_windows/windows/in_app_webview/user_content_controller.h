#ifndef FLUTTER_INAPPWEBVIEW_PLUGIN_USER_CONTENT_CONTROLLER_H_
#define FLUTTER_INAPPWEBVIEW_PLUGIN_USER_CONTENT_CONTROLLER_H_

#include <functional>
#include <map>
#include <vector>
#include <nlohmann/json.hpp>

#include "../plugin_scripts_js/javascript_bridge_js.h"
#include "../plugin_scripts_js/plugin_scripts_util.h"
#include "../types/content_world.h"
#include "../types/plugin_script.h"
#include "../types/user_script.h"

namespace flutter_inappwebview_plugin
{
  class InAppWebView;

  const std::string USER_SCRIPTS_AT_DOCUMENT_END_WRAPPER_JS_SOURCE = "window.addEventListener('load', () => { \
    if (window." + JAVASCRIPT_BRIDGE_NAME + " != null && (window." + JAVASCRIPT_BRIDGE_NAME + "._userScript" + VAR_PLACEHOLDER_MEMORY_ADDRESS_VALUE + "AtDocumentEndLoaded == null || !window." + JAVASCRIPT_BRIDGE_NAME + "._userScript" + VAR_PLACEHOLDER_MEMORY_ADDRESS_VALUE + "AtDocumentEndLoaded)) { \
      window." + JAVASCRIPT_BRIDGE_NAME + "._userScript" + VAR_PLACEHOLDER_MEMORY_ADDRESS_VALUE + "AtDocumentEndLoaded = true; \
      " + VAR_PLACEHOLDER_VALUE + " \
    } \
  });";

  class UserContentController
  {
  public:
    UserContentController(InAppWebView* webView);
    ~UserContentController();

    std::vector<std::shared_ptr<UserScript>> getUserOnlyScriptsAt(const UserScriptInjectionTime& injectionTime) const;
    void addUserOnlyScript(std::shared_ptr<UserScript> userScript);
    void addUserOnlyScripts(std::vector<std::shared_ptr<UserScript>> userScripts);
    void removeUserOnlyScript(std::shared_ptr<UserScript> userScript);
    void removeUserOnlyScriptAt(const int64_t& index, const UserScriptInjectionTime& injectionTime);
    void removeAllUserOnlyScripts();
    bool containsUserOnlyScript(std::shared_ptr<UserScript> userScript) const;
    bool containsUserOnlyScriptByGroupName(const std::string& groupName) const;
    void removeUserOnlyScriptsByGroupName(const std::string& groupName);

    std::vector<std::shared_ptr<PluginScript>> getPluginScriptsAt(const UserScriptInjectionTime& injectionTime) const;
    void addPluginScript(std::shared_ptr<PluginScript> pluginScript);
    void addPluginScripts(std::vector<std::shared_ptr<PluginScript>> pluginScripts);
    void removePluginScript(std::shared_ptr<PluginScript> pluginScript);
    void removeAllPluginScripts();
    bool containsPluginScript(std::shared_ptr<PluginScript> pluginScript) const;
    bool containsPluginScript(std::shared_ptr<PluginScript> pluginScript, const std::shared_ptr<ContentWorld> contentWorld) const;
    bool containsPluginScriptByGroupName(const std::string& groupName) const;
    void removePluginScriptsByGroupName(const std::string& groupName);
    std::vector<std::shared_ptr<PluginScript>> getPluginScriptsRequiredInAllContentWorlds() const;

    void initializeMethod(const wchar_t* name, const std::string& parameters,
      std::function<void(const nlohmann::json&)> onResult = nullptr);

    void whenScriptsReady(std::function<void(HRESULT)> completion) const;
    void registerEventHandlers();
    void createContentWorld(const std::shared_ptr<ContentWorld> contentWorld, const std::function<void(int)> completionHandler);
  private:
    InAppWebView* webView_;
    const std::shared_ptr<bool> alive_ = std::make_shared<bool>(true);
    struct ExecutionContext {
      std::string uniqueId;
      std::string frameId;
    };
    std::map<int, ExecutionContext> executionContexts_;
    struct PendingScripts {
      int count = 0;
      HRESULT error = S_OK;
      std::vector<std::function<void(HRESULT)>> completions;
    };
    const std::shared_ptr<PendingScripts> pendingScripts_ = std::make_shared<PendingScripts>();

    // used to track Content World names -> Execution Context ID
    std::map<std::string, int> contentWorlds_;
    // used only to track plugin script to inject inside new Content Worlds
    std::map<std::string, std::vector<std::shared_ptr<PluginScript>>> pluginScriptsInContentWorlds_;

    std::map<UserScriptInjectionTime, std::vector<std::shared_ptr<PluginScript>>> pluginScripts_ = {
      {UserScriptInjectionTime::atDocumentStart, {}},
      {UserScriptInjectionTime::atDocumentEnd, {}}
    };

    std::map<UserScriptInjectionTime, std::vector<std::shared_ptr<UserScript>>> userOnlyScripts_ = {
      {UserScriptInjectionTime::atDocumentStart, {}},
      {UserScriptInjectionTime::atDocumentEnd, {}}
    };

    void addScriptToWebView(std::shared_ptr<UserScript> userScript, const std::function<void(std::string)> completionHandler) const;
    void removeScriptFromWebView(std::shared_ptr<UserScript> userScript, const std::function<void()> completionHandler) const;

    void addPluginScriptsIfRequired(const std::shared_ptr<ContentWorld> contentWorld);
  };
}
#endif //FLUTTER_INAPPWEBVIEW_PLUGIN_USER_CONTENT_CONTROLLER_H_
