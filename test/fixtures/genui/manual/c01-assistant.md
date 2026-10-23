Synthetic, manually authored fixture. No model call or factual data.

The result updates locally when the parameter changes.

```kelivo-ui
ui 1 catalog "kelivo.native/1"
root = Column(children=[input,result,reset])
$a: number = 2
let doubled = $a * 2
input = Slider(label="Example parameter", bind=$a, min=0, max=10, step=1)
result = Metric(label="Example result", value=doubled)
reset = Button(label="Reset", action=Reset())
```
