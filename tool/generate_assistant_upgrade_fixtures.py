#!/usr/bin/env python3
"""Run historical Assistant writers; never recreate old fixtures with today's codec.

Requires the repository's tags/history and an installed Flutter dependency graph.
The regular upgrade tests consume the committed JSON and need neither git nor
historical source files. Run from any directory with Python 3.
"""

import hashlib
import json
from pathlib import Path
import re
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parent.parent
MODEL = "lib/core/models/assistant.dart"
OUTPUT = ROOT / "test/fixtures/assistants/historical_writers.json"
CONFIGURED = {
    "id": "old-configured",
    "name": "自定义助手 🧪",
    "avatar": "https://example.com/avatar.png",
    "useAssistantAvatar": True,
    "useAssistantName": True,
    "chatModelProvider": "provider-a",
    "chatModelId": "model-a",
    "temperature": 0.75,
    "topP": 0.9,
    "contextMessageSize": 1024,
    "limitContextMessages": True,
    "streamOutput": False,
    "thinkingBudget": 8192,
    "reasoning": {"level": "high", "budgetTokens": 8192},
    "maxTokens": 8192,
    "systemPrompt": "测试系统提示词",
    "messageTemplate": "{{ message }}\n{{ model_name }}",
    "searchEnabled": True,
    "mcpServerIds": ["mcp-a"],
    "localToolIds": ["terminal_exec"],
    "defaultWorkspaceId": "workspace-a",
    "defaultWorkspaceSetup": "completed",
    "skillIds": ["skill-a"],
    "healthDataTypeIds": ["steps", "sleep"],
    "background": "#123456",
    "useGradientBackground": True,
    "gradientBackgroundAnimated": False,
    "gradientBackgroundPhase": 5.5,
    "gradientBackgroundOffsetX": 0.3,
    "gradientBackgroundOffsetY": -0.4,
    "customHeaders": [{"name": "X-Test", "value": "a"}],
    "customBody": [{"key": "test", "value": '{"a":1}'}],
    "enableMemory": True,
    "autoOrganizeMemory": True,
    "memoryOrganizeEveryNTurns": 3,
    "memorySmartAddMode": "perItem",
    "memoryWriteScope": "alwaysAssistant",
    "allowPastConversationRecall": True,
    "enableRecentChatsReference": True,
    "generateConversationSummary": True,
    "recentChatsSummaryMessageCount": 10,
    "appendCurrentTimeToUserMessage": True,
    "useIso8601TimeFormat": True,
    "allowConversationSystemPrompt": True,
    "allowConversationPromptInjection": True,
    "deletable": False,
    "presetMessages": [
        {"id": "preset-a", "role": "user", "content": "hello"},
        {"id": "preset-b", "role": "assistant", "content": "你好"},
    ],
    "regexRules": [{
        "id": "regex-a", "name": "test", "pattern": "a", "replacement": "b",
        "scopes": ["user", "assistant"], "visualOnly": False,
        "replaceOnly": True, "enabled": True,
    }],
}


def git(*args):
    return subprocess.check_output(["git", *args], cwd=ROOT, text=True).strip()


def collect_sources(commit, path, sources):
    if path in sources:
        return
    source = subprocess.check_output(
        ["git", "show", f"{commit}:{path}"], cwd=ROOT, text=True,
    )
    sources[path] = source
    for dependency in re.findall(r"(?:import|export) ['\"]([^'\"]+)['\"]", source):
        if ":" not in dependency:
            collect_sources(commit, str(Path(path).parent / dependency), sources)


def main():
    refs = git("tag", "--list", "--sort=version:refname").splitlines()
    refs += git(
        "log", "--format=%H", "HEAD", "--", MODEL,
        "lib/core/models/assistant_regex.dart", "lib/core/models/preset_message.dart",
    ).splitlines()
    writers = {}
    with tempfile.TemporaryDirectory(prefix="kelivo-assistant-writers-") as temporary:
        work = Path(temporary)
        for ref in refs:
            commit = git("rev-parse", ref + "^{commit}")
            sources = {}
            collect_sources(commit, MODEL, sources)
            digest = hashlib.sha256(
                json.dumps(sources, sort_keys=True).encode(),
            ).hexdigest()
            if digest not in writers:
                index = len(writers)
                for path, source in sources.items():
                    target = work / f"writer_{index}" / path
                    target.parent.mkdir(parents=True, exist_ok=True)
                    target.write_text(source)
                writers[digest] = {
                    "commit": commit, "refs": [], "sourceSha256": digest,
                }
            writers[digest]["refs"].append(ref)

        imports = "\n".join(
            f"import '{work}/writer_{i}/{MODEL}' as old{i};"
            for i in range(len(writers))
        )
        captures = "\n".join(
            f"capture(old{i}.Assistant(id: 'old-default', name: '默认助手').toJson(), "
            f"old{i}.Assistant.fromJson(configured).toJson());"
            for i in range(len(writers))
        )
        (work / "configured.json").write_text(json.dumps(CONFIGURED))
        probe = work / "writer_test.dart"
        probe.write_text(f"""
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
{imports}
void main() {{
  test('serialize historical assistants', () {{
    final configured = Map<String, dynamic>.from(
      jsonDecode(File('{work}/configured.json').readAsStringSync()) as Map,
    );
    final payloads = <Object>[];
    void capture(Map<String, dynamic> defaults, Map<String, dynamic> custom) {{
      payloads.add([defaults, custom]);
    }}
    {captures}
    File('{work}/payloads.json').writeAsStringSync(jsonEncode(payloads));
  }});
}}
""")
        subprocess.run(
            ["flutter", "test", "--no-pub", str(probe), "--reporter", "expanded"],
            cwd=ROOT, check=True,
        )
        payloads = json.loads((work / "payloads.json").read_text())
        if len(payloads) != len(writers):
            raise RuntimeError("Historical writer output is incomplete")
        cases = {}
        for writer, assistants in zip(writers.values(), payloads):
            key = json.dumps(assistants, sort_keys=True)
            if key not in cases:
                cases[key] = {"writers": [], "assistants": assistants}
            cases[key]["writers"].append(writer)
        OUTPUT.parent.mkdir(parents=True, exist_ok=True)
        OUTPUT.write_text(json.dumps(list(cases.values()), ensure_ascii=False, indent=2) + "\n")
        print(f"Wrote {len(cases)} payload cases from {len(writers)} writers to {OUTPUT}")


if __name__ == "__main__":
    main()
