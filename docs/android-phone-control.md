# Android 手机控制

入口在「设置 → 手机控制」，也可以从「助手 → 本地工具 → 手机控制」或对话工具菜单开启。

需要同时完成两项配置：

1. 在 Android 无障碍设置中启用「Kelivo 手机控制」。页面会分别显示未启用、已启用但未连接、已连接三种状态。
2. 允许当前助手使用「手机控制」。每个助手单独配置，默认关闭。关闭后，已经开始的工具循环也无法继续发起新的手机控制调用。

下载的 APK 在部分系统上需要先到应用信息菜单选择「允许受限制的设置」。任务运行时需保持设备解锁。

## 工具行为

`phone_control` 通过现有的 `app.device_tools` MethodChannel 调用 Android `AccessibilityService`：

- `read_screen`：读取当前活动窗口的可见无障碍节点、屏幕尺寸与快照标识。
- `tap` / `long_press`：按节点或屏幕坐标点击、长按。
- `set_text`：替换可编辑节点的文本，空字符串清空。若节点的 `supports_set_text` 为 false，先点击输入框获得焦点，再重新读取界面后输入。
- `scroll` / `swipe`：滚动节点或执行坐标滑动。
- `back` / `home` / `recents` / `notifications` / `quick_settings`：系统导航。
- `list_apps` / `open_app`：查询可启动应用并按包名打开。

节点与坐标操作需要最近一次 `read_screen` 的 `snapshot_id`。快照最多保留 30 秒；新读取和操作会使旧快照失效。

- 节点操作：窗口、布局、文字、状态描述和滚动事件会触发快照重验，节点集合、文字或状态变化后需重新读取；节点只是位置漂移不算变化，因为操作作用于节点本身而非坐标。执行前还会刷新目标节点并校验内容和勾选等状态。
- 坐标手势：校验快照标识与时效、仍是同一应用窗口、屏幕尺寸未变，但不比较内容，因此可以用于短视频、直播等持续刷新的界面。同一窗口内界面自行切换（开屏广告结束、弹出应用内对话框）不会被拦截，模型应在界面可能已变化时重新读取。

手势等待系统回调，拒绝、取消和超时均返回结构化错误。每次操作后应重新读取界面确认结果。

无障碍查询和操作在串行后台线程执行，快照也由该线程统一管理。服务中断或断开时立即结束待回复的请求，取消尚未执行的操作；已经发出的系统调用不能强行撤回，但返回后不会继续执行后续操作。

后台任务一旦调用手机控制（任意动作），Kelivo 的悬浮胶囊会隐藏，直到所有后台任务结束；这类任务结束后也不显示完成胶囊。手势是真实触摸，胶囊若留在目标应用上方会接住点击并把 Kelivo 切回前台。

当前依赖应用提供的无障碍节点，不提供图像识别、截图或 Shizuku 命令。完全通过画布绘制且不提供无障碍信息的控件可能无法识别。

密码节点及其子节点的文本不返回给模型。无障碍事件只用于触发快照重验，不收集事件文本或持续录屏。主动读取到的屏幕内容会作为对话工具结果保存，并发送给该对话配置的模型服务商；首次为助手开启时会显示此说明。

## 验证

```sh
flutter test test/features/home/services/phone_control_test.dart
cd android
./gradlew :app:testDebugUnitTest --tests com.psyche.kelivo.PhoneControlServiceTest
```

端到端测试使用无账号的测试界面和 Android 系统设置，覆盖真实读取、点击、长按、输入、滚动、启动应用和返回桌面：

```sh
flutter test integration_test/phone_control_test.dart -d <android-device-id>
```

安装测试 APK 后，需要在测试设备的系统设置中启用服务。测试会等待授权 45 秒；应在模拟器或专用测试设备上执行。

原生能力及服务声明参考 [Android AccessibilityService API](https://developer.android.com/reference/android/accessibilityservice/AccessibilityService)，实现结构参考本地 OpenMinis 的 `MinisAccessibilityService`、`NodeRegistry` 和 `AccessibilityOffloadHandler`。
