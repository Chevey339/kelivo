# Complete examples

All values below are synthetic example data. Each reply includes prose outside its fence.

## calculator

Change the controls to explore this local example.

```kelivo-ui
ui 1 catalog "kelivo.native/1"
root = Column(children=[quantityInput,result,reset])
$quantity: number = 3
quantityInput = Slider(label="Example quantity", bind=$quantity, min=0, max=10)
result = Metric(label="Example total", value=$quantity * 12, unit="USD")
reset = Button(label="Reset locally", action=Reset())
```

## curve

Change the controls to explore this local example.

```kelivo-ui
ui 1 catalog "kelivo.native/1"
root = Column(children=[slopeInput,chart,table])
$slope: number = 2
let points = @sample(x => $slope * x + 1, -2, 2, 21)
slopeInput = Slider(label="Example slope", bind=$slope, min=-5, max=5, step=0.1)
chart = Chart(kind="line", data=points, x="x", y=["y"], title="Synthetic function")
table = DataTable(data=points, rowKey="x", columns=[{"key":"x","label":"x"},{"key":"y","label":"y"}])
```

## conditional-form

Change the controls to explore this local example.

```kelivo-ui
ui 1 catalog "kelivo.native/1"
root = Column(children=[form,result,ask])
$useOffset: boolean = true
$offset: number = 1
let total = 10 + ($useOffset ? $offset : 0)
form = Form(children=[toggle,offsetInput], title="Example parameters")
toggle = Switch(label="Use offset", bind=$useOffset)
offsetInput = NumberField(label="Offset", bind=$offset, visible=$useOffset, required=true)
result = Metric(label="Example result", value=total, unit="u")
ask = Button(label="Prepare explanation draft", form=form, action=Ask(text="Explain these example parameters.", context={"useOffset":$useOffset,"offset":$offset,"result":total}))
```
