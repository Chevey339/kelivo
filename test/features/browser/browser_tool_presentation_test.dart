import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:Kelivo/features/browser/models/browser_tool_presentation.dart';
import 'package:Kelivo/l10n/app_localizations_zh.dart';
import 'package:Kelivo/utils/mcp_structured_image.dart';

void main() {
  final l = AppLocalizationsZh();
  BrowserToolAction action(
    String name, {
    Map<String, dynamic> args = const {},
    Object? page,
    String? raw,
  }) => BrowserToolAction(
    id: name,
    arguments: {'action': name, ...args},
    content: raw ?? jsonEncode({'ok': true, 'page': page}),
  );
  test(
    'preview height estimate follows collapsed cards without an operations row',
    () {
      expect(estimateBrowserGroupBodyHeight(lite: false), 76);
      expect(estimateBrowserGroupBodyHeight(lite: true), 48);
    },
  );
  test(
    'preview belongs to result metadata, with explicit screenshots as fallback',
    () {
      BrowserToolAction saved(Map<String, dynamic> metadata) =>
          BrowserToolAction(
            id: 'step',
            arguments: const {'action': 'snapshot'},
            metadata: metadata,
            content:
                '{"ok":true,"page":{"previewImage":"file:///untrusted.png"}}',
          );
      expect(saved({}).previewImage, isNull);
      expect(
        saved({
          kMcpResultMetadataKey: mcpResultMetadata(['own-screenshot']),
        }).previewImage,
        'own-screenshot',
      );
      expect(
        saved({
          'browser': {'previewImage': 'own-preview'},
          kMcpResultMetadataKey: mcpResultMetadata(['own-screenshot']),
        }).previewImage,
        'own-preview',
      );
    },
  );
  test('every browser operation has a localized label', () {
    const labels = {
      'open': '打开网页',
      'new_tab': '新建标签页',
      'render': '渲染页面',
      'extract': '提取正文',
      'snapshot': '读取页面结构',
      'click': '点击',
      'type': '输入文字',
      'press': '按键',
      'scroll': '滚动页面',
      'wait': '等待页面',
      'back': '后退',
      'forward': '前进',
      'reload': '刷新页面',
      'evaluate': '执行脚本',
      'switch_tab': '切换标签页',
      'close_tab': '关闭标签页',
      'list_tabs': '查看标签页',
      'unknown': '浏览器操作',
    };
    for (final entry in labels.entries) {
      expect(browserActionLabel(l, entry.key), entry.value);
    }
  });
  test('image suffix and malformed result never break presentation', () {
    expect(
      action(
        'open',
        raw:
            '{"ok":true,"page":{"title":"Result","url":"https://www.example.com/path?q=1"}}\n![](file.png)',
      ).title,
      'Result',
    );
    expect(action('open', raw: 'not JSON').failed, isFalse);
    expect(action('open', raw: '[1,2]').hasPage, isFalse);
    expect(action('open', raw: '{"page":"wrong shape"}').hasPage, isFalse);
    expect(browserUrlLabel('https://www.example.com/path?q=1'), 'example.com');
    expect(
      browserUrlLabel('https://www.example.com/path?q=1', includePath: true),
      'example.com/path',
    );
  });
  test(
    'click resolves only nearest preceding snapshot and falls back to selector',
    () {
      final old = action(
        'snapshot',
        page: {
          'elements': [
            {'ref': 'r1', 'name': 'Old'},
          ],
        },
      );
      final current = action(
        'snapshot',
        page: {
          'elements': [
            {'ref': 'r1', 'name': 'Releases'},
          ],
        },
      );
      expect(
        action('click', args: {'ref': 'r1'}).target(l, [old, current]),
        '「Releases」',
      );
      final empty = action('snapshot', page: {'elements': []});
      expect(
        action(
          'click',
          args: {'ref': 'r1', 'selector': '#download'},
        ).target(l, [old, empty]),
        '「#download」',
      );
      expect(action('click', args: {'ref': 'r2'}).target(l, [current]), isNull);
      expect(
        action('extract', page: {'content': '字' * 3200}).target(l, []),
        '3.2k 字',
      );
      expect(
        action(
          'snapshot',
          page: {
            'elements': [{}, {}],
          },
        ).target(l, []),
        '2 个元素',
      );
      expect(
        action('type', args: {'text': '😀' * 30}).target(l, []),
        '「${'😀' * 24}…」',
      );
    },
  );
  test(
    'errors map to bounded explanations and metadata failure is honored',
    () {
      for (final entry in {
        'browser_agent_disabled': '浏览器控制未开启',
        'stale_ref': '元素已失效，需重新读取页面',
        'element_not_visible': '元素不可见或被遮挡',
        'element_covered': '元素不可见或被遮挡',
        'element_not_found': '未找到元素',
        'TimeoutException': '页面加载超时',
        'timeout': '页面加载超时',
        'browser_action_timeout_outcome_unknown': '操作超时，结果未确认，请检查页面后允许继续',
        'browser_human_control': '你正在接管浏览器',
        'browser_tab_not_found': '标签页已关闭',
        'browser_tab_closed': '标签页已关闭',
        'secret/path': '操作失败',
      }.entries) {
        expect(browserErrorSummary(l, entry.key), entry.value);
      }
      expect(
        BrowserToolAction(
          id: 'x',
          arguments: const {},
          metadata: {
            'browser': {'status': 'error', 'tabId': 'tab'},
          },
        ).failed,
        isTrue,
      );
    },
  );
}
