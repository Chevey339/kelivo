#include <nlohmann/json.hpp>
#include <wil/wrl.h>

#include "../utils/log.h"
#include "../utils/string.h"
#include "../utils/vector.h"
#include "in_app_webview.h"
#include "user_content_controller.h"

namespace flutter_inappwebview_plugin
{
  using namespace Microsoft::WRL;

  UserContentController::UserContentController(InAppWebView* webView)
    : webView_(webView)
  {}

  void UserContentController::registerEventHandlers()
  {
    if (!webView_ || !webView_->webView) return;

    // Subscribe before enabling Runtime: it immediately reports existing
    // contexts. Keep frame/unique-context identities through popup handoff.
    auto listen = [this](const wchar_t* name, std::function<void(const nlohmann::json&)> handler) {
      wil::com_ptr<ICoreWebView2DevToolsProtocolEventReceiver> receiver;
      auto hr = webView_->webView->GetDevToolsProtocolEventReceiver(name, &receiver);
      if (FAILED(hr)) { pendingScripts_->error = hr; return; }
      hr = receiver->add_DevToolsProtocolEventReceived(
        Callback<ICoreWebView2DevToolsProtocolEventReceivedEventHandler>(
          [alive = alive_, handler](ICoreWebView2*, ICoreWebView2DevToolsProtocolEventReceivedEventArgs* args) {
            if (!*alive) return S_OK;
            wil::unique_cotaskmem_string raw;
            if (SUCCEEDED(args->get_ParameterObjectAsJson(&raw)) && raw) {
              const auto event = nlohmann::json::parse(wide_to_utf8(raw.get()), nullptr, false);
              if (event.is_object()) handler(event);
            }
            return S_OK;
          }).Get(), nullptr);
      if (FAILED(hr)) pendingScripts_->error = hr;
    };
    listen(L"Runtime.executionContextCreated", [this](const nlohmann::json& event) {
      if (!event.contains("context") || !event["context"].is_object()) return;
      const auto& context = event["context"];
      if (!context.contains("id") || !context["id"].is_number_integer() ||
        !context.contains("uniqueId") || !context["uniqueId"].is_string() ||
        !context.contains("auxData") || !context["auxData"].is_object()) return;
      const auto& aux = context["auxData"];
      if (!aux.contains("frameId") || !aux["frameId"].is_string()) return;
      const int id = context["id"].get<int>();
      const bool isDefault = aux.contains("isDefault") && aux["isDefault"] == true;
      const auto name = isDefault ? ContentWorld::page()->name : context.value("name", std::string());
      executionContexts_.insert_or_assign(id, ExecutionContext{ context["uniqueId"], aux["frameId"] });
      if (aux["frameId"] == webView_->pageFrameId()) {
        contentWorlds_.insert_or_assign(name, id);
        if (!isDefault) addPluginScriptsIfRequired(std::make_shared<ContentWorld>(name));
      }
    });
    listen(L"Runtime.executionContextDestroyed", [this](const nlohmann::json& event) {
      if (!event.contains("executionContextId") || !event["executionContextId"].is_number_integer()) return;
      const int id = event["executionContextId"].get<int>();
      executionContexts_.erase(id);
      for (auto it = contentWorlds_.begin(); it != contentWorlds_.end();) {
        if (it->second == id) it = contentWorlds_.erase(it);
        else ++it;
      }
    });
    listen(L"Runtime.executionContextsCleared", [this](const nlohmann::json&) {
      executionContexts_.clear();
      contentWorlds_.clear();
    });
    listen(L"Page.frameNavigated", [this](const nlohmann::json& event) {
      if (!event.contains("frame") || !event["frame"].is_object()) return;
      const auto& frame = event["frame"];
      if (!frame.contains("parentId") && frame.contains("id") && frame["id"].is_string()) {
        webView_->setPageFrameId(frame["id"].get<std::string>());
      }
    });
    listen(L"Runtime.bindingCalled", [this](const nlohmann::json& event) {
      if (!event.contains("name") || event["name"] != JAVASCRIPT_BRIDGE_BINDING_NAME ||
        !event.contains("payload") || !event["payload"].is_string() ||
        !event.contains("executionContextId") || !event["executionContextId"].is_number_integer()) return;
      const int contextId = event["executionContextId"].get<int>();
      const auto context = executionContexts_.find(contextId);
      // Runtime bindings exist in subframes too. Preserve WebMessageReceived's
      // top-level-only boundary using native context metadata, not a JS claim.
      if (context == executionContexts_.end() || webView_->pageFrameId().empty() ||
        context->second.frameId != webView_->pageFrameId() || !webView_->channelDelegate) return;
      const auto message = nlohmann::json::parse(event["payload"].get<std::string>(), nullptr, false);
      if (!message.is_object() || !message.contains("name") || message["name"] != "callHandler" ||
        !message.contains("body") || !message["body"].is_object()) return;
      const auto& body = message["body"];
      if (!body.contains("handlerName") || !body["handlerName"].is_string() ||
        !body.contains("_callHandlerID") || !body["_callHandlerID"].is_number_integer() ||
        !body.contains("args") || !body["args"].is_string()) return;
      const auto uniqueId = context->second.uniqueId;
      const auto callId = body["_callHandlerID"].get<int64_t>();
      auto reply = [this, alive = alive_, contextId, uniqueId, callId](const std::string& value, bool error) {
        if (!*alive) return;
        const auto current = executionContexts_.find(contextId);
        if (current == executionContexts_.end() || current->second.uniqueId != uniqueId) return;
        auto json = nlohmann::json::parse(value, nullptr, false);
        if (json.is_discarded()) json = nullptr;
        const auto target = "window." + JAVASCRIPT_BRIDGE_NAME + "[" + std::to_string(callId) + "]";
        const auto source = "if (" + target + ") { " + target +
          (error ? ".reject(new Error(" + nlohmann::json(value).dump() + "))" : ".resolve(" + json.dump() + ")") +
          "; delete " + target + "; }";
        // An integer context id can be reused after navigation. CDP's unique id
        // also protects against navigation between this check and evaluation.
        const nlohmann::json parameters = { { "expression", source }, { "uniqueContextId", uniqueId } };
        failedLog(webView_->webView->CallDevToolsProtocolMethod(L"Runtime.evaluate", utf8_to_wide(parameters.dump()).c_str(), nullptr));
      };
      auto callback = std::make_unique<WebViewChannelDelegate::CallJsHandlerCallback>();
      callback->defaultBehaviour = [reply](const std::optional<const flutter::EncodableValue*> response) {
        const auto value = response.has_value() ? std::get_if<std::string>(*response) : nullptr;
        reply(value ? *value : "null", false);
      };
      callback->error = [reply](const std::string& code, const std::string& message, const flutter::EncodableValue*) {
        reply(code + ", " + message, true);
      };
      webView_->channelDelegate->onCallJsHandler(body["handlerName"].get<std::string>(), body["args"].get<std::string>(), std::move(callback));
    });

    initializeMethod(L"Runtime.enable", "{}", [this](const nlohmann::json&) {
      initializeMethod(L"Runtime.addBinding", nlohmann::json({ { "name", JAVASCRIPT_BRIDGE_BINDING_NAME } }).dump());
    });
    initializeMethod(L"Page.enable", "{}", [this](const nlohmann::json&) {
      initializeMethod(L"Page.getFrameTree", "{}", [this](const nlohmann::json& tree) {
        if (tree.contains("frameTree") && tree["frameTree"].contains("frame") &&
          tree["frameTree"]["frame"].contains("id") && tree["frameTree"]["frame"]["id"].is_string()) {
          webView_->setPageFrameId(tree["frameTree"]["frame"]["id"].get<std::string>());
        }
      });
    });
  }

  void UserContentController::initializeMethod(const wchar_t* name, const std::string& parameters,
    std::function<void(const nlohmann::json&)> onResult)
  {
    ++pendingScripts_->count;
    auto finish = [alive = alive_, pending = pendingScripts_, onResult](HRESULT hr, LPCWSTR raw) {
      if (*alive && SUCCEEDED(hr) && onResult) {
        const auto result = raw ? nlohmann::json::parse(wide_to_utf8(raw), nullptr, false) : nlohmann::json();
        if (result.is_object()) onResult(result);
        else hr = E_FAIL;
      }
      if (FAILED(hr)) pending->error = hr;
      if (--pending->count == 0) {
        auto callbacks = std::move(pending->completions);
        pending->completions.clear();
        if (*alive) for (const auto& callback : callbacks) callback(pending->error);
      }
      return S_OK;
    };
    const auto hr = webView_->webView->CallDevToolsProtocolMethod(name, utf8_to_wide(parameters).c_str(),
      Callback<ICoreWebView2CallDevToolsProtocolMethodCompletedHandler>(finish).Get());
    if (FAILED(hr)) finish(hr, nullptr);
  }

  std::vector<std::shared_ptr<UserScript>> UserContentController::getUserOnlyScriptsAt(const UserScriptInjectionTime& injectionTime) const
  {
    return userOnlyScripts_.at(injectionTime);
  }

  void UserContentController::addUserOnlyScript(std::shared_ptr<UserScript> userScript)
  {
    if (!userScript) {
      return;
    }

    addPluginScriptsIfRequired(userScript->contentWorld);
    addScriptToWebView(userScript, nullptr);
    userOnlyScripts_.at(userScript->injectionTime).push_back(std::move(userScript));
  }

  void UserContentController::addUserOnlyScripts(std::vector<std::shared_ptr<UserScript>> userScripts)
  {
    for (auto& userScript : userScripts) {
      addUserOnlyScript(std::move(userScript));
    }
  }

  void UserContentController::removeUserOnlyScript(std::shared_ptr<UserScript> userScript)
  {
    if (!userScript) {
      return;
    }

    if (webView_) {
      removeScriptFromWebView(userScript, nullptr);
    }

    vector_remove_erase(userOnlyScripts_.at(userScript->injectionTime), std::move(userScript));
  }

  void UserContentController::removeUserOnlyScriptAt(const int64_t& index, const UserScriptInjectionTime& injectionTime)
  {
    auto& vec = userOnlyScripts_.at(injectionTime);
    int64_t size = vec.size();
    if (index >= size) {
      return;
    }

    auto& userScript = vec.at(index);
    if (userScript) {
      removeScriptFromWebView(userScript, nullptr);
      vec.erase(vec.begin() + index);
    }
  }

  void UserContentController::removeAllUserOnlyScripts()
  {
    auto& userScriptsAtStart = userOnlyScripts_.at(UserScriptInjectionTime::atDocumentStart);
    auto& userScriptsAtEnd = userOnlyScripts_.at(UserScriptInjectionTime::atDocumentEnd);

    if (webView_) {
      for (auto& userScript : userScriptsAtStart) {
        removeScriptFromWebView(userScript, nullptr);
      }
      for (auto& userScript : userScriptsAtEnd) {
        removeScriptFromWebView(userScript, nullptr);
      }
    }

    userScriptsAtStart.clear();
    userScriptsAtEnd.clear();
  }

  void UserContentController::removeUserOnlyScriptsByGroupName(const std::string& groupName)
  {
    std::vector<std::shared_ptr<UserScript>> userScriptsAtStart = userOnlyScripts_.at(UserScriptInjectionTime::atDocumentStart);
    std::vector<std::shared_ptr<UserScript>> userScriptsAtEnd = userOnlyScripts_.at(UserScriptInjectionTime::atDocumentEnd);

    for (auto& userScript : userScriptsAtStart) {
      if (string_equals(groupName, userScript->groupName)) {
        removeUserOnlyScript(userScript);
      }
    }

    for (auto& userScript : userScriptsAtEnd) {
      if (string_equals(groupName, userScript->groupName)) {
        removeUserOnlyScript(userScript);
      }
    }
  }

  std::vector<std::shared_ptr<PluginScript>> UserContentController::getPluginScriptsAt(const UserScriptInjectionTime& injectionTime) const
  {
    return pluginScripts_.at(injectionTime);
  }

  bool UserContentController::containsUserOnlyScript(std::shared_ptr<UserScript> userScript) const
  {
    if (!userScript) {
      return false;
    }

    return vector_contains(userOnlyScripts_.at(userScript->injectionTime), std::move(userScript));
  }

  bool UserContentController::containsUserOnlyScriptByGroupName(const std::string& groupName) const
  {
    return vector_contains_if(userOnlyScripts_.at(UserScriptInjectionTime::atDocumentStart), [groupName](const std::shared_ptr<UserScript> userScript) { return string_equals(groupName, userScript->groupName); }) ||
      vector_contains_if(userOnlyScripts_.at(UserScriptInjectionTime::atDocumentEnd), [groupName](const std::shared_ptr<UserScript> userScript) { return string_equals(groupName, userScript->groupName); });
  }

  void UserContentController::addPluginScript(std::shared_ptr<PluginScript> pluginScript)
  {
    if (!pluginScript) {
      return;
    }

    addScriptToWebView(pluginScript, nullptr);
    pluginScripts_.at(pluginScript->injectionTime).push_back(std::move(pluginScript));
  }

  void UserContentController::addPluginScripts(std::vector<std::shared_ptr<PluginScript>> pluginScripts)
  {
    for (auto& pluginScript : pluginScripts) {
      addPluginScript(std::move(pluginScript));
    }
  }

  void UserContentController::removePluginScript(std::shared_ptr<PluginScript> pluginScript)
  {
    if (!pluginScript) {
      return;
    }

    if (webView_) {
      removeScriptFromWebView(pluginScript, nullptr);
    }

    vector_remove_erase(pluginScripts_.at(pluginScript->injectionTime), std::move(pluginScript));
  }

  void UserContentController::removeAllPluginScripts()
  {
    auto& pluginScriptsAtStart = pluginScripts_.at(UserScriptInjectionTime::atDocumentStart);
    auto& pluginScriptsAtEnd = pluginScripts_.at(UserScriptInjectionTime::atDocumentEnd);

    if (webView_) {
      for (auto& pluginScript : pluginScriptsAtStart) {
        removeScriptFromWebView(pluginScript, nullptr);
      }
      for (auto& pluginScript : pluginScriptsAtEnd) {
        removeScriptFromWebView(pluginScript, nullptr);
      }
    }

    pluginScriptsAtStart.clear();
    pluginScriptsAtEnd.clear();
  }

  bool UserContentController::containsPluginScript(std::shared_ptr<PluginScript> pluginScript) const
  {
    if (!pluginScript) {
      return false;
    }

    auto injectionTime = pluginScript->injectionTime;
    return vector_contains(pluginScripts_.at(injectionTime), std::move(pluginScript));
  }


  bool UserContentController::containsPluginScript(std::shared_ptr<PluginScript> pluginScript, const std::shared_ptr<ContentWorld> contentWorld) const
  {
    if (!pluginScript || !map_contains(pluginScriptsInContentWorlds_, contentWorld->name)) {
      return false;
    }

    return vector_contains(pluginScriptsInContentWorlds_.at(contentWorld->name), std::move(pluginScript));
  }

  bool UserContentController::containsPluginScriptByGroupName(const std::string& groupName) const
  {
    return vector_contains_if(pluginScripts_.at(UserScriptInjectionTime::atDocumentStart), [groupName](const std::shared_ptr<PluginScript> pluginScript) { return string_equals(groupName, pluginScript->groupName); }) ||
      vector_contains_if(pluginScripts_.at(UserScriptInjectionTime::atDocumentEnd), [groupName](const std::shared_ptr<PluginScript> pluginScript) { return string_equals(groupName, pluginScript->groupName); });
  }

  void UserContentController::removePluginScriptsByGroupName(const std::string& groupName)
  {
    std::vector<std::shared_ptr<PluginScript>> pluginScriptsAtStart = pluginScripts_.at(UserScriptInjectionTime::atDocumentStart);
    std::vector<std::shared_ptr<PluginScript>> pluginScriptsAtEnd = pluginScripts_.at(UserScriptInjectionTime::atDocumentEnd);

    for (auto& pluginScript : pluginScriptsAtStart) {
      if (string_equals(groupName, pluginScript->groupName)) {
        removePluginScript(pluginScript);
      }
    }

    for (auto& pluginScript : pluginScriptsAtEnd) {
      if (string_equals(groupName, pluginScript->groupName)) {
        removePluginScript(pluginScript);
      }
    }
  }


  std::vector<std::shared_ptr<PluginScript>> UserContentController::getPluginScriptsRequiredInAllContentWorlds() const
  {
    std::vector<std::shared_ptr<PluginScript>> res;

    std::vector<std::shared_ptr<PluginScript>> pluginScriptsAtStart = pluginScripts_.at(UserScriptInjectionTime::atDocumentStart);
    std::vector<std::shared_ptr<PluginScript>> pluginScriptsAtEnd = pluginScripts_.at(UserScriptInjectionTime::atDocumentEnd);

    for (auto& pluginScript : pluginScriptsAtStart) {
      if (!pluginScript->contentWorld && pluginScript->isRequiredInAllContentWorlds()) {
        res.push_back(pluginScript);
      }
    }

    for (auto& pluginScript : pluginScriptsAtEnd) {
      if (!pluginScript->contentWorld && pluginScript->isRequiredInAllContentWorlds()) {
        res.push_back(pluginScript);
      }
    }

    return res;
  }

  void UserContentController::createContentWorld(const std::shared_ptr<ContentWorld> contentWorld, const std::function<void(int)> completionHandler)
  {
    if (!webView_ || !(webView_->webView) || ContentWorld::isPage(contentWorld)) {
      if (completionHandler) {
        completionHandler(-1);
      }
      return;
    }

    auto& worldName = contentWorld->name;
    if (!map_contains(contentWorlds_, worldName)) {
      nlohmann::json parameters = {
        {"frameId", webView_->pageFrameId()},
        {"worldName", worldName}
      };
      auto hr = webView_->webView->CallDevToolsProtocolMethod(L"Page.createIsolatedWorld", utf8_to_wide(parameters.dump()).c_str(), Callback<ICoreWebView2CallDevToolsProtocolMethodCompletedHandler>(
        [this, completionHandler, worldName](HRESULT errorCode, LPCWSTR returnObjectAsJson)
        {
          if (succeededOrLog(errorCode) && completionHandler) {
            auto id = nlohmann::json::parse(wide_to_utf8(returnObjectAsJson))["executionContextId"].get<int>();
            addPluginScriptsIfRequired(std::make_shared<ContentWorld>(worldName));
            completionHandler(id);
          }
          return S_OK;
        }
      ).Get());
      if (failedAndLog(hr) && completionHandler) {
        completionHandler(-1);
      }
    }
    else if (completionHandler) {
      completionHandler(contentWorlds_.at(worldName));
    }
  }

  void UserContentController::whenScriptsReady(std::function<void(HRESULT)> completion) const
  {
    if (pendingScripts_->count == 0) completion(pendingScripts_->error);
    else pendingScripts_->completions.push_back(std::move(completion));
  }

  void UserContentController::addScriptToWebView(std::shared_ptr<UserScript> userScript, const std::function<void(std::string)> completionHandler) const
  {
    if (!webView_ || !(webView_->webView)) {
      if (completionHandler) {
        completionHandler(userScript->id);
      }
      return;
    }

    std::string source = userScript->source;
    if (userScript->injectionTime == UserScriptInjectionTime::atDocumentEnd) {
      source = replace_all_copy(USER_SCRIPTS_AT_DOCUMENT_END_WRAPPER_JS_SOURCE, VAR_PLACEHOLDER_VALUE, source);
      std::ostringstream address;
      address << std::addressof(userScript);
      replace_all(source, VAR_PLACEHOLDER_MEMORY_ADDRESS_VALUE, address.str());
    }

    if (!userScript->contentWorld || ContentWorld::isPage(userScript->contentWorld)) {
      ++pendingScripts_->count;
      auto finish = [pending = pendingScripts_, userScript, completionHandler](HRESULT hr, LPCWSTR id)
        {
          if (SUCCEEDED(hr) && id) userScript->id = "native:" + wide_to_utf8(id);
          else pending->error = FAILED(hr) ? hr : E_FAIL;
          if (completionHandler) completionHandler(userScript->id);
          if (--pending->count == 0) {
            auto callbacks = std::move(pending->completions);
            pending->completions.clear();
            for (const auto& callback : callbacks) callback(pending->error);
          }
          return S_OK;
        };
      const auto hr = webView_->webView->AddScriptToExecuteOnDocumentCreated(utf8_to_wide(source).c_str(),
        Callback<ICoreWebView2AddScriptToExecuteOnDocumentCreatedCompletedHandler>(finish).Get());
      if (FAILED(hr)) finish(hr, nullptr);
      return;
    }

    nlohmann::json parameters = {
      {"source", source}
    };

    if (userScript->contentWorld && !ContentWorld::isPage(userScript->contentWorld)) {
      parameters["worldName"] = userScript->contentWorld->name;
    }

    auto hr = webView_->webView->CallDevToolsProtocolMethod(L"Page.addScriptToEvaluateOnNewDocument", utf8_to_wide(parameters.dump()).c_str(), Callback<ICoreWebView2CallDevToolsProtocolMethodCompletedHandler>(
      [userScript, completionHandler](HRESULT errorCode, LPCWSTR returnObjectAsJson)
      {
        if (succeededOrLog(errorCode)) {
          nlohmann::json json = nlohmann::json::parse(wide_to_utf8(returnObjectAsJson));
          userScript->id = json["identifier"].get<std::string>();
        }
        if (completionHandler) {
          completionHandler(userScript->id);
        }
        return S_OK;
      }
    ).Get());

    if (failedAndLog(hr) && completionHandler) {
      completionHandler(userScript->id);
    }
  }

  void UserContentController::removeScriptFromWebView(std::shared_ptr<UserScript> userScript, const std::function<void()> completionHandler) const
  {
    if (!webView_ || !(webView_->webView)) {
      if (completionHandler) {
        completionHandler();
      }
      return;
    }

    if (userScript->id.rfind("native:", 0) == 0) {
      failedLog(webView_->webView->RemoveScriptToExecuteOnDocumentCreated(utf8_to_wide(userScript->id.substr(7)).c_str()));
      if (completionHandler) completionHandler();
      return;
    }

    nlohmann::json parameters = {
      {"identifier", userScript->id}
    };

    auto hr = webView_->webView->CallDevToolsProtocolMethod(L"Page.removeScriptToEvaluateOnNewDocument", utf8_to_wide(parameters.dump()).c_str(), Callback<ICoreWebView2CallDevToolsProtocolMethodCompletedHandler>(
      [userScript, completionHandler](HRESULT errorCode, LPCWSTR returnObjectAsJson)
      {
        failedLog(errorCode);
        if (completionHandler) {
          completionHandler();
        }
        return S_OK;
      }
    ).Get());

    if (failedAndLog(hr) && completionHandler) {
      completionHandler();
    }
  }

  void UserContentController::addPluginScriptsIfRequired(const std::shared_ptr<ContentWorld> contentWorld)
  {
    if (contentWorld && !ContentWorld::isPage(contentWorld)) {
      std::vector<std::shared_ptr<PluginScript>> pluginScriptsRequiredInAllContentWorlds = getPluginScriptsRequiredInAllContentWorlds();
      for (auto& pluginScript : pluginScriptsRequiredInAllContentWorlds) {
        if (!containsPluginScript(pluginScript, contentWorld)) {
          if (!map_contains(pluginScriptsInContentWorlds_, contentWorld->name)) {
            pluginScriptsInContentWorlds_.insert({ contentWorld->name, {} });
          }
          pluginScriptsInContentWorlds_.at(contentWorld->name).push_back(pluginScript);
          addPluginScript(pluginScript->copyAndSet(contentWorld));
        }
      }
    }
  }

  UserContentController::~UserContentController()
  {
    debugLog("dealloc UserContentController");
    *alive_ = false;
    pendingScripts_->completions.clear();
    removeAllUserOnlyScripts();
    removeAllPluginScripts();
    contentWorlds_.clear();
    pluginScriptsInContentWorlds_.clear();
    webView_ = nullptr;
  }
}
