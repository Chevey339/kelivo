import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/theme/theme_factory.dart';
import 'package:Kelivo/shared/widgets/ios_tactile.dart';
import 'package:Kelivo/shared/widgets/ios_text_button.dart';
import 'package:Kelivo/features/settings/widgets/custom_theme_widgets.dart';
import '../../catalog/ui_catalog.dart';
import '../../runtime/ui_surface_controller.dart';
import '../../runtime/ui_surface_state.dart';
import '../../host/ui_web_document.dart';
import '../../host/ui_web_preview.dart';
import '../../host/gallery/web_gallery.dart';
import '../genui_expansion.dart';
import '../genui_surface.dart';
import '../genui_theme.dart';
import '../genui_web_card.dart';
import 'content_gallery.dart';
import 'input_gallery.dart';
import 'chart_gallery.dart';
import 'table_gallery.dart';
import 'context_gallery.dart';
import 'scenario_sources.dart';

/// Isolated native visual review entry. Never imported by the production app.
/// All data is synthetic; changing a fixture cannot send a provider request.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(GenUiReviewGalleryApp(fontFamily: await loadGenUiReviewFont()));
}

/// Optional local QA asset; production imports neither this entry nor the font.
Future<String?> loadGenUiReviewFont() async {
  const asset = String.fromEnvironment('GENUI_REVIEW_FONT_ASSET');
  if (asset.isEmpty) return null;
  final loader = FontLoader('GenUIReviewFont')..addFont(rootBundle.load(asset));
  await loader.load();
  return 'GenUIReviewFont';
}

const genUiReviewCases = [
  '内容与布局',
  '表单',
  '表单错误',
  '禁用输入',
  '预算与饼图',
  '折线图',
  '面积图',
  '柱状图',
  '散点图',
  '定义域缺口',
  '空图表',
  '长表格',
  '空表格',
  '附带状态与弹窗',
  '流式骨架',
  '节点错误',
  '已中断',
  '无效界面',
  '尚未保存',
  '只读快照',
  '网页预览',
  '长消息',
  'S1',
  'S2',
  'S3',
  'S4',
  'S5',
  'S6',
];

class GenUiReviewGalleryApp extends StatefulWidget {
  const GenUiReviewGalleryApp({super.key, this.fontFamily});
  final String? fontFamily;
  @override
  State<GenUiReviewGalleryApp> createState() => _GenUiReviewGalleryAppState();
}

class _GenUiReviewGalleryAppState extends State<GenUiReviewGalleryApp> {
  bool _dark = false, _large = false, _rtl = false, _header = true;
  int _case = 0;
  final _scroll = ScrollController();
  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _select(int value) {
    if (_scroll.hasClients) _scroll.jumpTo(0);
    setState(() => _case = value);
  }

  Future<void> _menu(BuildContext context) async {
    final value = await showAppDialog<int>(
      context,
      maxWidth: 420,
      child: Builder(
        builder: (context) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppDialogHeader(title: '组件检查'),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    for (var i = 0; i < genUiReviewCases.length; i++)
                      IosTextButton(
                        label: genUiReviewCases[i],
                        onPressed: () => Navigator.of(context).pop(i),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
    if (mounted && value != null) _select(value);
  }

  ThemeData _reviewTheme() {
    final theme = _dark ? buildDarkTheme(null) : buildLightTheme(null);
    final font = widget.fontFamily;
    return font == null
        ? theme
        : theme.copyWith(
            textTheme: theme.textTheme.apply(fontFamily: font),
            primaryTextTheme: theme.primaryTextTheme.apply(fontFamily: font),
          );
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: _reviewTheme(),
    locale: const Locale('zh'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(_large ? 1.3 : 1)),
      child: Directionality(
        textDirection: _rtl ? TextDirection.rtl : TextDirection.ltr,
        child: child!,
      ),
    ),
    home: Builder(
      builder: (context) => Scaffold(
        appBar: AppBar(
          title: Text(genUiReviewCases[_case]),
          actions: [
            IosIconButton(
              key: const ValueKey('review-menu'),
              icon: LucideIcons.list,
              tooltip: '组件检查',
              onTap: () => _menu(context),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IosTextButton(
                    key: const ValueKey('review-theme'),
                    label: _dark ? '深色' : '浅色',
                    onPressed: () => setState(() => _dark = !_dark),
                  ),
                  IosTextButton(
                    key: const ValueKey('review-scale'),
                    label: _large ? '1.3×' : '1×',
                    onPressed: () => setState(() => _large = !_large),
                  ),
                  IosTextButton(
                    key: const ValueKey('review-direction'),
                    label: _rtl ? 'RTL' : 'LTR',
                    onPressed: () => setState(() => _rtl = !_rtl),
                  ),
                  IosTextButton(
                    key: const ValueKey('review-header'),
                    label: _header ? '标题栏' : '沉浸',
                    onPressed: () => setState(() => _header = !_header),
                  ),
                ],
              ),
              Expanded(
                child: SingleChildScrollView(
                  key: const ValueKey('review-scroll'),
                  controller: _scroll,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: GenUiThemeScope(
                          child: SelectionArea(
                            child: KeyedSubtree(
                              key: ValueKey(_case),
                              child: _content(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IosTextButton(
                    key: const ValueKey('review-previous'),
                    label: '上一项',
                    onPressed: _case == 0 ? null : () => _select(_case - 1),
                  ),
                  Text('${_case + 1} / ${genUiReviewCases.length}'),
                  IosTextButton(
                    key: const ValueKey('review-next'),
                    label: '下一项',
                    onPressed: _case + 1 == genUiReviewCases.length
                        ? null
                        : () => _select(_case + 1),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
  Widget _content() => switch (genUiReviewCases[_case]) {
    '内容与布局' => const GenUiContentGallery(),
    '表单' => const GenUiInputGallery(showIntent: false),
    '表单错误' => const GenUiInputGallery(validation: true, showIntent: false),
    '禁用输入' => const GenUiInputGallery(enabled: false, showIntent: false),
    '预算与饼图' => _ReviewSurface(source: genUiReviewBudget, showHeader: _header),
    '折线图' => const GenUiChartGallery(kind: 'line'),
    '面积图' => const GenUiChartGallery(kind: 'area'),
    '柱状图' => _ReviewSurface(source: genUiReviewBars, showHeader: _header),
    '散点图' => const GenUiChartGallery(kind: 'scatter'),
    '定义域缺口' => const GenUiChartGallery(kind: 'gaps'),
    '空图表' => const GenUiChartGallery(kind: 'empty'),
    '长表格' => const GenUiTableGallery(),
    '空表格' => const GenUiTableGallery(kind: 'table-empty'),
    '附带状态与弹窗' => const GenUiContextGallery(),
    '流式骨架' => const _ReviewStream(),
    '节点错误' => const _ReviewSurface(
      source:
          'root = Column(children=[good,bad])\ngood = Metric(label="有效结果",value=42)\nbad = Gauge(value=3)',
    ),
    '已中断' => const _ReviewSurface(
      source:
          'root = Column(children=[good,pending])\ngood = Metric(label="有效结果",value=42)',
      generation: UiGenerationStatus.interrupted,
    ),
    '无效界面' => const _ReviewSurface(
      source: 'ui 9 catalog "kelivo.native/1"\nroot = Text(text="无效协议")',
    ),
    '尚未保存' => const _ReviewSurface(
      source: 'root = Metric(label="当前值",value=42)',
      unsaved: true,
    ),
    '只读快照' => _ReviewSurface(source: genUiReviewBudget, exporting: true),
    '网页预览' => const _ReviewWeb(),
    '长消息' => Column(
      children: [
        _ReviewSurface(
          source: genUiScenarioSources['S6']!,
          showHeader: _header,
        ),
        const SizedBox(height: 16),
        _ReviewSurface(source: genUiReviewBudget, showHeader: _header),
        const Padding(
          padding: EdgeInsets.all(20),
          child: Text('后续消息：已经滚动到两个完整交互界面之后。'),
        ),
      ],
    ),
    final name => _ReviewSurface(
      source: genUiScenarioSources[name]!,
      showHeader: _header,
    ),
  };
}

class _ReviewSurface extends StatefulWidget {
  const _ReviewSurface({
    required this.source,
    this.showHeader = true,
    this.unsaved = false,
    this.exporting = false,
    this.generation = UiGenerationStatus.complete,
  });
  final String source;
  final bool showHeader, unsaved, exporting;
  final UiGenerationStatus generation;
  @override
  State<_ReviewSurface> createState() => _ReviewSurfaceState();
}

class _ReviewSurfaceState extends State<_ReviewSurface> {
  late final controller =
      UiSurfaceController(
        owner: const UiSurfaceOwner(revisionId: 'review', surfaceKey: '0:0'),
      )..updateSource(
        '${widget.source.startsWith('ui ') ? '' : '${UiCatalog.header}\n'}${widget.source}\n',
        closed: widget.generation == UiGenerationStatus.complete,
        generation: widget.generation,
      );
  @override
  void initState() {
    super.initState();
    if (widget.unsaved) {
      controller.setSaveFailed(
        true,
        token: controller.token,
        sequence: controller.sequence,
      );
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GenUiExpansion(
    surfaceBuilder: (expand, focus, expanded) => GenUiSurface(
      controller: controller,
      showHeader: widget.showHeader,
      exporting: widget.exporting,
      onExpand: expand,
      expandFocusNode: focus,
      expanded: expanded,
      onAsk: (_) async {},
      onRepair: () {},
      onRetrySave: () => controller.setSaveFailed(
        false,
        token: controller.token,
        sequence: controller.sequence,
      ),
    ),
  );
}

class _ReviewStream extends StatefulWidget {
  const _ReviewStream();
  @override
  State<_ReviewStream> createState() => _ReviewStreamState();
}

class _ReviewStreamState extends State<_ReviewStream> {
  final controller = UiSurfaceController(
    owner: const UiSurfaceOwner(revisionId: 'review-stream', surfaceKey: '0:0'),
  );
  int _step = 0;
  static const lines = [
    UiCatalog.header,
    'root = Column(children=[chart,result,form])',
    'chart = Chart(kind="line",title="月度趋势",data=points,x="x",y=["y"])',
    'result = Metric(label="合计",value=total,unit="元")',
    'form = Form(children=[nameField])',
    r'$name: string = ""',
    r'nameField = TextField(label="备注",bind=$name)',
    'let total = 5500',
    'let points = [{"x":1,"y":2},{"x":2,"y":3},{"x":3,"y":5}]',
  ];
  void _update() => controller.updateSource(
    '${lines.take(_step + 1).join('\n')}\n',
    closed: _step == lines.length,
    generation: _step == lines.length
        ? UiGenerationStatus.complete
        : UiGenerationStatus.generating,
  );
  @override
  void initState() {
    super.initState();
    _update();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Row(
        children: [
          IosTextButton(
            key: const ValueKey('review-stream-step'),
            label: _step == lines.length ? '重新生成' : '到达下一条记录',
            onPressed: () {
              setState(() => _step = (_step + 1) % (lines.length + 1));
              _update();
            },
          ),
          IosTextButton(
            key: const ValueKey('review-stream-interrupt'),
            label: '中断',
            onPressed: () => controller.updateSource(
              controller.parsed.source,
              closed: false,
              generation: UiGenerationStatus.interrupted,
            ),
          ),
        ],
      ),
      GenUiSurface(controller: controller),
    ],
  );
}

class _ReviewWeb extends StatelessWidget {
  const _ReviewWeb();
  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final state in [
        'ready',
        'dark',
        'streaming',
        'invalid',
        'unsupported',
      ]) ...[
        GenUiWebCard(
          document: UiWebDocument.parse(
            state == 'invalid'
                ? '{"version":9}\n<body>Invalid</body>'
                : state == 'dark'
                ? genUiWebDarkGallerySource
                : genUiWebGallerySource,
            closed: state != 'streaming',
            generation: state == 'streaming'
                ? UiGenerationStatus.generating
                : UiGenerationStatus.complete,
          ),
          supported: state != 'unsupported',
          onOpen: (document) => showUiWebPreview(context, document),
        ),
        const SizedBox(height: 12),
      ],
    ],
  );
}

const genUiReviewBudget = r'''ui 1 catalog "kelivo.native/1"
$budget: number = 5500
let data = [{"category":"房租","share":35,"amount":$budget*0.35},{"category":"餐饮","share":25,"amount":$budget*0.25},{"category":"交通","share":12,"amount":$budget*0.12},{"category":"娱乐","share":10,"amount":$budget*0.10},{"category":"储蓄","share":18,"amount":$budget*0.18}]
root = Column(children=[budgetInput,total,chart,table])
budgetInput = Slider(label="月度可用金额",bind=$budget,min=1000,max=20000,step=100,unit="元")
total = Metric(label="合计分配",value=$budget,unit="元")
chart = Chart(kind="pie",title="支出与储蓄占比",data=data,x="category",y=["amount"],unit="元",donut=true)
table = DataTable(data=data,rowKey="category",columns=[{"key":"category","label":"类别"},{"key":"share","label":"占比 (%)"},{"key":"amount","label":"金额 (元)","digits":0}])
''';
const genUiReviewBars =
    r'''root = Chart(kind="bar",title="季度销售额（万元）",x="季度",y=["华东","华北","华南"],unit="万元",xLabel="季度",yLabel="销售额",data=[{"季度":"Q1","华东":120,"华北":95,"华南":78},{"季度":"Q2","华东":134,"华北":102,"华南":88},{"季度":"Q3","华东":152,"华北":118,"华南":96},{"季度":"Q4","华东":170,"华北":130,"华南":110}])''';
