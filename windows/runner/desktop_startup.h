#ifndef RUNNER_DESKTOP_STARTUP_H_
#define RUNNER_DESKTOP_STARTUP_H_

#include <windows.h>

#include <string>
#include <vector>

namespace desktop_startup {
constexpr wchar_t kRunKey[] = L"Software\\Microsoft\\Windows\\CurrentVersion\\Run";
constexpr wchar_t kApprovalKey[] =
    L"Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\StartupApproved\\Run";
constexpr wchar_t kValueName[] = L"Kelivo";

inline std::wstring Command() {
  std::vector<wchar_t> path(32768);
  const DWORD size = GetModuleFileNameW(nullptr, path.data(), static_cast<DWORD>(path.size()));
  if (size == 0 || size >= path.size()) return {};
  return L"\"" + std::wstring(path.data(), size) + L"\" --autostart";
}

inline LSTATUS IsEnabled(bool* enabled) {
  *enabled = false;
  DWORD bytes = 0;
  LSTATUS status = RegGetValueW(HKEY_CURRENT_USER, kRunKey, kValueName,
                              RRF_RT_REG_SZ, nullptr, nullptr, &bytes);
  if (status == ERROR_FILE_NOT_FOUND || status == ERROR_PATH_NOT_FOUND) return ERROR_SUCCESS;
  if (status != ERROR_SUCCESS) return status;
  std::vector<wchar_t> value(bytes / sizeof(wchar_t) + 1, 0);
  status = RegGetValueW(HKEY_CURRENT_USER, kRunKey, kValueName,
                       RRF_RT_REG_SZ, nullptr, value.data(), &bytes);
  if (status != ERROR_SUCCESS) return status;
  if (std::wstring(value.data()) != Command()) return ERROR_SUCCESS;
  BYTE approval[12] = {};
  bytes = sizeof(approval);
  status = RegGetValueW(HKEY_CURRENT_USER, kApprovalKey, kValueName,
                       RRF_RT_REG_BINARY, nullptr, approval, &bytes);
  if (status == ERROR_FILE_NOT_FOUND || status == ERROR_PATH_NOT_FOUND) {
    *enabled = true;
    return ERROR_SUCCESS;
  }
  if (status != ERROR_SUCCESS) return status;
  *enabled = bytes == 0 || (approval[0] % 2 == 0);
  return ERROR_SUCCESS;
}

inline LSTATUS SetEnabled(bool enabled) {
  const auto command = Command();
  if (command.empty()) return ERROR_BAD_PATHNAME;
  HKEY key = nullptr;
  LSTATUS status = RegCreateKeyExW(HKEY_CURRENT_USER, kRunKey, 0, nullptr, 0,
                                  KEY_SET_VALUE, nullptr, &key, nullptr);
  if (status != ERROR_SUCCESS) return status;
  if (enabled) {
    status = RegSetValueExW(key, kValueName, 0, REG_SZ,
                           reinterpret_cast<const BYTE*>(command.c_str()),
                           static_cast<DWORD>((command.size() + 1) * sizeof(wchar_t)));
  } else {
    status = RegDeleteValueW(key, kValueName);
    if (status == ERROR_FILE_NOT_FOUND) status = ERROR_SUCCESS;
  }
  RegCloseKey(key);
  if (status != ERROR_SUCCESS) return status;
  // An explicit in-app toggle may re-enable an entry disabled in Task Manager.
  status = RegCreateKeyExW(HKEY_CURRENT_USER, kApprovalKey, 0, nullptr, 0,
                          KEY_SET_VALUE, nullptr, &key, nullptr);
  if (status != ERROR_SUCCESS) return status;
  if (enabled) {
    const BYTE approval[12] = {2};
    status = RegSetValueExW(key, kValueName, 0, REG_BINARY, approval, sizeof(approval));
  } else {
    status = RegDeleteValueW(key, kValueName);
    if (status == ERROR_FILE_NOT_FOUND) status = ERROR_SUCCESS;
  }
  RegCloseKey(key);
  return status;
}
}  // namespace desktop_startup
#endif
