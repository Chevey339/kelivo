import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:markstream/markstream_core.dart';

import 'package:Kelivo/icons/lucide_adapter.dart';

/// Only visible rows are widgets, even when an expanded container has many nodes.
class MarkdownAstView extends StatefulWidget {
  const MarkdownAstView({super.key, required this.document});
  final DocumentNode document;
  @override
  State<MarkdownAstView> createState() => _MarkdownAstViewState();
}

class _MarkdownAstViewState extends State<MarkdownAstView> {
  final _expanded = <String>{'document:0:root'};
  @override
  Widget build(BuildContext context) {
    final visible = <(MarkdownNode, int, String)>[];
    final pending = <(MarkdownNode, int, String)>[(widget.document, 0, 'root')];
    while (pending.isNotEmpty) {
      final row = pending.removeLast();
      visible.add(row);
      final node = row.$1, key = '${node.type}:${node.span.start}:${row.$3}';
      if (_expanded.contains(key)) {
        for (var i = node.children.length - 1; i >= 0; i--) {
          pending.add((node.children[i], row.$2 + 1, '${row.$3}/$i'));
        }
      }
    }
    return ListView.builder(
      key: const ValueKey('markdown-playground-ast'),
      primary: false,
      padding: const EdgeInsets.all(8),
      itemCount: visible.length,
      itemBuilder: (context, index) {
        final (node, depth, path) = visible[index];
        final key = '${node.type}:${node.span.start}:$path';
        final fields = node is DocumentNode
            ? {
                'children': node.children.length,
                'references': node.references.length,
              }
            : {
                for (final entry in node.fields.entries)
                  entry.key:
                      entry.value is String &&
                          (entry.value! as String).length > 160
                      ? '${(entry.value! as String).substring(0, 160)}…'
                      : entry.value,
              };
        final summary = jsonEncode(fields);
        final expandable = node.children.isNotEmpty,
            open = _expanded.contains(key);
        return Padding(
          key: ValueKey(key),
          padding: EdgeInsetsDirectional.only(
            start: (depth * 12.0).clamp(0, 120),
          ),
          child: Semantics(
            expanded: expandable ? open : null,
            child: Material(
              type: MaterialType.transparency,
              child: ListTile(
                dense: true,
                leading: expandable
                    ? Icon(
                        open ? Lucide.ChevronDown : Lucide.ChevronRight,
                        size: 16,
                      )
                    : const SizedBox(width: 16),
                title: Text(
                  '${node.type} [${node.span.start}, ${node.span.end})',
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
                subtitle: fields.isEmpty
                    ? null
                    : Text(
                        summary,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                onTap: expandable
                    ? () => setState(() {
                        if (open) {
                          _expanded.remove(key);
                        } else {
                          _expanded.add(key);
                        }
                      })
                    : null,
              ),
            ),
          ),
        );
      },
    );
  }
}
