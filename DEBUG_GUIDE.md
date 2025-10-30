# Flutter Windows 桌面端调试指南

## 🔧 主要调试方法

### 1. **Flutter DevTools (推荐)**
```bash
# 启动开发模式运行应用
flutter run -d windows

# 在另一个终端启动 DevTools
flutter pub global activate devtools
flutter pub global run devtools
```

**DevTools 功能：**
- 🌐 **Network Inspector** - 查看所有HTTP请求
- 🔍 **Inspector** - 检查UI组件树
- 📊 **Performance** - 性能分析
- 🐛 **Debugger** - 断点调试
- 💾 **Memory** - 内存使用情况

### 2. **命令行调试模式**
```bash
# 详细日志模式
flutter run -d windows -v

# 仅显示错误和警告
flutter run -d windows --debug

# 性能分析模式
flutter run -d windows --profile
```

### 3. **查看网络请求**

#### 方法A: 使用 DevTools
1. 启动应用: `flutter run -d windows`
2. 启动 DevTools: `flutter pub global run devtools`
3. 打开浏览器访问显示的URL (通常是 http://127.0.0.1:9100)
4. 点击 "Network" 标签页

#### 方法B: 代码中添加日志
```dart
import 'package:http/http.dart' as http;
import 'dart:developer' as developer;

Future<void> makeRequest() async {
  try {
    developer.log('开始请求: GET https://api.example.com/data');

    final response = await http.get(Uri.parse('https://api.example.com/data'));

    developer.log('请求完成: 状态码 ${response.statusCode}');
    developer.log('响应内容: ${response.body}');

  } catch (e) {
    developer.log('请求失败: $e', level: 1000);
  }
}
```

#### 方法C: 使用 dio 库的拦截器
```dart
import 'package:dio/dio.dart';

Dio createDio() {
  Dio dio = Dio();

  // 添加请求拦截器
  dio.interceptors.add(LogInterceptor(
    requestBody: true,
    responseBody: true,
    requestHeader: true,
    responseHeader: true,
    error: true,
    logPrint: (obj) {
      developer.log(obj.toString());
    },
  ));

  return dio;
}
```

### 4. **查看错误和日志**

#### 控制台日志
```dart
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

// 不同级别的日志
developer.log('普通信息');
developer.log('警告信息', level: 900);
developer.log('错误信息', level: 1000);

// 条件日志
if (kDebugMode) {
  print('调试信息: $data');
}
```

#### 错误处理和调试
```dart
import 'dart:developer' as developer;

class MyWidget extends StatefulWidget {
  @override
  _MyWidgetState createState() => _MyWidgetState();
}

class _MyWidgetState extends State<MyWidget> {
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final result = await someAsyncOperation();
      developer.log('数据加载成功: $result');
      setState(() {
        // 更新UI
      });
    } catch (e, stackTrace) {
      developer.log('数据加载失败', error: e, stackTrace: stackTrace);

      // 在调试模式下显示错误
      if (kDebugMode) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('错误: $e')),
        );
      }
    }
  }
}
```

### 5. **UI调试**

#### Flutter Inspector
```bash
flutter run -d windows --debug
# 按 'p' 键进入Inspector模式
# 或者点击VSCode的Flutter Inspector扩展
```

#### Widget树调试
```dart
import 'package:flutter/rendering.dart';

void main() {
  // 在调试模式下显示Widget边界
  debugPaintSizeEnabled = kDebugMode;
  runApp(MyApp());
}
```

### 6. **性能调试**

#### 性能分析
```bash
# 性能模式运行
flutter run -d windows --profile

# 生成性能报告
flutter build windows --profile --analyze-size
```

#### 代码中性能监控
```dart
import 'package:flutter/foundation.dart';

Future<void> expensiveOperation() async {
  if (kDebugMode) {
    final stopwatch = Stopwatch()..start();
    await performExpensiveTask();
    stopwatch.stop();
    print('耗时: ${stopwatch.elapsedMilliseconds}ms');
  } else {
    await performExpensiveTask();
  }
}
```

### 7. **常见调试快捷键**

在 `flutter run` 模式下：
- `r` - 热重载
- `R` - 热重启
- `p` - 显示网格
- `o` - 切换平台
- `P` - 性能叠加层
- `s` - 截图
- `a` - 断开连接
- `q` - 退出

### 8. **VSCode调试配置**

在 `.vscode/launch.json` 中添加：
```json
{
    "name": "kelivo_windows",
    "request": "launch",
    "type": "dart",
    "program": "lib/main.dart",
    "args": ["-d", "windows"]
}
```

### 9. **实际使用建议**

#### 开发流程：
1. **开发阶段**: `flutter run -d windows`
2. **调试网络**: 启动 DevTools 查看 Network 标签
3. **性能优化**: `flutter run -d windows --profile`
4. **发布前**: `flutter build windows --release`

#### 网络调试最佳实践：
```dart
import 'dart:developer' as developer;

class ApiService {
  static Future<void> makeRequest() async {
    final url = Uri.parse('https://api.example.com/data');

    try {
      developer.log('🚀 请求开始: $url');

      final response = await http.get(url).timeout(Duration(seconds: 10));

      developer.log('✅ 响应成功: ${response.statusCode}');
      developer.log('📦 响应数据: ${response.body}');

    } on TimeoutException {
      developer.log('⏰ 请求超时', level: 1000);
    } on SocketException {
      developer.log('🔌 网络连接失败', level: 1000);
    } catch (e, stackTrace) {
      developer.log('❌ 请求失败: $e', error: e, stackTrace: stackTrace, level: 1000);
    }
  }
}
```

### 10. **推荐的调试工具组合**

1. **开发时**: VSCode + Flutter插件 + 控制台日志
2. **网络调试**: Flutter DevTools Network Inspector
3. **性能调试**: Flutter DevTools Performance Tab
4. **UI调试**: Flutter Inspector + debugPaintSizeEnabled
5. **错误追踪**: try-catch + developer.log + stackTrace

这样你就能全面监控Windows桌面端的运行状况了！