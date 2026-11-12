# Semantic text coverage

Copy, read-aloud and export use readable values from the current accepted state,
not DSL source. Search uses source defaults; later input changes do not update
the search index or make changed results searchable. Hidden nodes are omitted; unavailable nodes contribute a
bounded explanation. Text/code/formula display does not execute nested UI.
Inputs expose labels/values/units; Metric includes its value/unit/trend; action labels and interface chrome are omitted from parameter/result text. Charts describe series, ranges and
gaps with a data alternative. Tables describe their columns and visible page.
Large results are bounded with an omission marker. An explicitly attached chip
freezes at click time and is not updated by later input changes.

- Badge: policy=text; fields=text.
- Button: policy=action; fields=label.
- Callout: policy=text; fields=title, text.
- Chart: policy=chart; fields=title, kind, xLabel, yLabel, unit, x, y, data.
- Checkbox: policy=input; fields=label, bind.
- Column: policy=layout; fields=children.
- DataTable: policy=table; fields=columns, data.
- Divider: policy=divider; fields=label.
- Form: policy=form; fields=title, children.
- Formula: policy=formula; fields=label, tex.
- Markdown: policy=text; fields=text.
- Metric: policy=metric; fields=label, value, unit, trend.
- NumberField: policy=input; fields=label, bind, unit.
- RadioGroup: policy=input; fields=label, bind, options.
- Row: policy=layout; fields=children.
- Section: policy=layout; fields=title, subtitle, children.
- Select: policy=input; fields=label, bind, options.
- Slider: policy=input; fields=label, bind, unit.
- Switch: policy=input; fields=label, bind.
- Text: policy=text; fields=text.
- TextField: policy=input; fields=label, bind.
