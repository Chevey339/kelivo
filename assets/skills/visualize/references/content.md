# content — kelivo.native/1

`*` means required. Omitted optional values are absent unless a default is shown.
All nodes also accept: visible:boolean (default=true), enabled:boolean (default=true).

## Badge
Short semantic status. Avoid conveying meaning by color alone.
`Badge(text*:string, tone:string (default="neutral"; oneOf=["neutral","primary","success","warning","error"]))`

## Callout
Explain a caveat or result. Avoid repeated decorative notices.
`Callout(text*:string, title:string, tone:string (default="info"; oneOf=["info","tip","warning","error","primary"]))`

## Column
Stack a short sequence. Avoid long app-like screens.
`Column(children*:[nodeId], gap:string (default="medium"; oneOf=["small","medium","large"]))`

## Divider
Separate groups. Avoid using it to encode data.
`Divider(label:string)`

## Formula
Display TeX with an optional spoken label. Computation belongs in expressions.
`Formula(label:string, tex*:string)`

## Markdown
Short formatted explanatory text. Avoid nested UI or interactive HTML.
`Markdown(text*:string)`

## Metric
Show a labelled number and unit. Avoid using it for paragraphs.
`Metric(digits:number (min=0.0; max=10.0; integer), label*:string, trend:number?, unit:string, value*:number?)`

## Row
Compare compact peers; wraps on narrow/large-text layouts. Avoid fixed-width assumptions.
`Row(children*:[nodeId], distribution:string (default="equal"; oneOf=["equal","fit"]), gap:string (default="medium"; oneOf=["small","medium","large"]))`

## Section
Group related content with a title. Avoid deeply nested framed sections.
`Section(children*:[nodeId], subtitle:string, title*:string, tone:string (default="info"; oneOf=["info","tip","warning","error","primary"]))`

## Text
Plain readable content. Avoid inventing typography properties.
`Text(text*:string, variant:string (default="body"; oneOf=["title","body","caption","mono"]))`

