import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import 'package:Kelivo/icons/lucide_adapter.dart';
import 'package:Kelivo/l10n/app_localizations.dart';
import 'package:Kelivo/shared/widgets/segmented_tabs.dart';
import 'package:Kelivo/theme/app_font_weights.dart';
import 'package:Kelivo/theme/app_semantic_colors.dart';

import 'code_file_preview.dart';
import 'preview_states.dart';

const int kCsvPreviewMaxRows = 200;

class CsvFilePreview extends StatefulWidget {
  const CsvFilePreview({super.key, required this.file, this.autoLoad = true});

  final File file;
  final bool autoLoad;

  @override
  CsvFilePreviewState createState() => CsvFilePreviewState();
}

class CsvFilePreviewState extends State<CsvFilePreview> {
  bool _showSource = false;
  String? _source;
  Object? _error;

  @override
  void initState() {
    super.initState();
    if (widget.autoLoad) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(load());
      });
    }
  }

  @visibleForTesting
  Future<void> load() async {
    try {
      final source = utf8.decode(
        widget.file.readAsBytesSync(),
        allowMalformed: true,
      );
      if (!mounted) return;
      setState(() {
        _source = source;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  String get _delimiter {
    return p.extension(widget.file.path).toLowerCase() == '.tsv' ? '\t' : ',';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (_error != null) {
      return PreviewError(onRetry: () => unawaited(load()));
    }
    final source = _source;
    if (source == null) {
      return const PreviewLoading();
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: SegmentedTabs(
            tabs: [
              SegmentedTab(
                label: l10n.workspacePreviewTable,
                icon: Lucide.FileSpreadsheet,
              ),
              SegmentedTab(
                label: l10n.workspacePreviewSource,
                icon: Lucide.FileCode,
              ),
            ],
            index: _showSource ? 1 : 0,
            onChanged: (next) => setState(() => _showSource = next == 1),
          ),
        ),
        Expanded(
          child: _showSource
              ? CodeFilePreview(
                  file: widget.file,
                  autoLoad: widget.autoLoad,
                  language: 'csv',
                )
              : source.trim().isEmpty
              ? PreviewEmptyHint(
                  title: l10n.workspacePreviewEmptyTable,
                  hint: l10n.workspacePreviewEmptyHint,
                  icon: Lucide.FileSpreadsheet,
                )
              : _CsvTableView(
                  rows: parseDelimitedRows(
                    source,
                    delimiter: _delimiter,
                    maxRows: kCsvPreviewMaxRows,
                  ),
                ),
        ),
      ],
    );
  }
}

class _CsvTableView extends StatelessWidget {
  const _CsvTableView({required this.rows});

  final List<List<String>> rows;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (rows.isEmpty) {
      return PreviewEmptyHint(
        title: l10n.workspacePreviewEmptyTable,
        hint: l10n.workspacePreviewEmptyHint,
        icon: Lucide.FileSpreadsheet,
      );
    }
    final cs = Theme.of(context).colorScheme;
    final fill = context.appColors.surfaceFill;
    final colCount = rows.fold<int>(
      0,
      (max, row) => row.length > max ? row.length : max,
    );
    final hairline = cs.onSurface.withValues(alpha: 0.08);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Scrollbar(
        child: SingleChildScrollView(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Table(
              defaultColumnWidth: const IntrinsicColumnWidth(),
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: [
                for (var r = 0; r < rows.length; r++)
                  TableRow(
                    decoration: BoxDecoration(
                      color: r == 0 ? fill : null,
                      border: Border(
                        bottom: BorderSide(color: hairline, width: 0.5),
                      ),
                    ),
                    children: [
                      for (var c = 0; c < colCount; c++)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          child: Text(
                            c < rows[r].length ? rows[r][c] : '',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: r == 0
                                  ? AppFontWeights.semibold
                                  : AppFontWeights.regular,
                            ),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

@visibleForTesting
List<List<String>> parseDelimitedRows(
  String source, {
  required String delimiter,
  int maxRows = kCsvPreviewMaxRows,
}) {
  final rows = <List<String>>[];
  var field = StringBuffer();
  var row = <String>[];
  var inQuotes = false;
  for (var i = 0; i < source.length; i++) {
    final ch = source[i];
    if (inQuotes) {
      if (ch == '"') {
        if (i + 1 < source.length && source[i + 1] == '"') {
          field.write('"');
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        field.write(ch);
      }
      continue;
    }
    if (ch == '"') {
      inQuotes = true;
      continue;
    }
    if (ch == delimiter) {
      row.add(field.toString());
      field = StringBuffer();
      continue;
    }
    if (ch == '\n') {
      row.add(field.toString());
      field = StringBuffer();
      rows.add(row);
      if (rows.length >= maxRows) return rows;
      row = <String>[];
      continue;
    }
    if (ch != '\r') {
      field.write(ch);
    }
  }
  if (field.isNotEmpty || row.isNotEmpty) {
    row.add(field.toString());
    rows.add(row);
  }
  return rows;
}
