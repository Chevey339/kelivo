# Generated visualize guidance

`UiCatalog` owns signatures, defaults, choices, limits and semantic field names.
`UiGuidance` supplies concise usage guidance and three fixed scenario templates;
its example builder checks every component/property against the catalog. The
runtime tests additionally parse, type-check and interact with all examples.

Regenerate offline with `dart run tool/genui_guidance.dart`; use `--check` to
verify committed assets. C22 prepares these files without registering a bundled
Skill or adding them to the asset manifest. C23 owns registration.

The manual evaluator uses the same Skill, protocol, component/function references
and examples. It still runs only on explicit manual invocation, outside G/CI.
The generated asset directory is included in its clean-input check.

`guidance-budget-c22.json` records tiktoken 0.12.0 measurements with cl100k_base
and o200k_base. These are reference BPE counts, not DeepSeek billing-token claims.
The tokenizer was installed only in ignored build/genui/c22/tokenizer; it is not
an application dependency or a prerequisite for G. To reproduce the input:

```sh
dart --packages=.dart_tool/package_config.json tool/genui_guidance.dart --budget-input > build/genui/guidance-budget-input.json
```

With tiktoken in an isolated Python environment, load that JSON and encode each
value with both named encodings. Limits are summary 300, main Skill 900, and all
component/function references plus all three examples 4,000 tokens. Unit tests
also enforce UTF-8 byte bounds (1.5 KiB summary, 3.6 KB main, 16 KB references)
and exact asset/template equality. Tokenizer vocabulary downloads are build
preparation; no model API or account credentials are involved.
