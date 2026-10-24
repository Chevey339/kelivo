/// Synthetic examples shared by the development gallery and acceptance probes.
/// Values illustrate local interaction; they are not factual recommendations.
const genUiScenarioSources = <String, String>{
  'S1': r'''ui 1 catalog "kelivo.native/1"
$speed: number = 30
$hours: number = 2
$initial: number = 5
let distance = $speed * $hours + $initial
root = Column(children=[intro,form,results,reset])
intro = Text(text="Example data · local distance calculator", variant="caption")
form = Form(children=[speedInput,hoursInput,initialInput])
speedInput = Slider(label="Speed", bind=$speed, min=0, max=100, step=1, unit="km/h")
hoursInput = NumberField(label="Duration", bind=$hours, min=0, max=24, step=0.5, unit="h")
initialInput = NumberField(label="Initial distance", bind=$initial, min=0, max=1000, unit="km")
results = Row(children=[result,rate])
result = Metric(label="Distance", value=distance, unit="km", digits=1)
rate = Metric(label="Speed", value=$speed, unit="km/h", digits=0)
reset = Button(label="Reset calculator", action=Reset())
''',
  'S2': r'''ui 1 catalog "kelivo.native/1"
$offset: number = 1
let points = @sample(x => @sqrt(x - $offset), -2, 4, 13)
root = Column(children=[intro,offsetInput,chart,table])
intro = Text(text="Example data · square-root domain", variant="caption")
offsetInput = Slider(label="Domain offset", bind=$offset, min=-2, max=4, step=0.5)
chart = Chart(kind="line", data=points, x="x", y=["y"], unit="u")
table = DataTable(data=points, rowKey="x", columns=[{"key":"x","label":"x"},{"key":"y","label":"y","digits":2}])
''',
  'S3': r'''ui 1 catalog "kelivo.native/1"
let points = [{"month":"Jan","North":12,"South":8,"West":10},{"month":"Feb","North":15,"South":null,"West":13},{"month":"Mar","North":11,"South":12,"West":16},{"month":"Apr","North":19,"South":15,"West":18}]
root = Column(children=[intro,chart])
intro = Text(text="Example data · regional trend, one missing observation", variant="caption")
chart = Chart(kind="line", data=points, x="month", y=["North","South","West"], unit="units")
''',
  'S4': r'''ui 1 catalog "kelivo.native/1"
let options = [{"id":"p01","name":"Plan 01","price":20,"score":99},{"id":"p02","name":"Plan 02","price":20,"score":98},{"id":"p03","name":"Plan 03","price":10,"score":97},{"id":"p04","name":"Plan 04","price":null,"score":96},{"id":"p05","name":"Plan 05","price":50,"score":95},{"id":"p06","name":"Plan 06","price":60,"score":94},{"id":"p07","name":"Plan 07","price":70,"score":93},{"id":"p08","name":"Plan 08","price":80,"score":92},{"id":"p09","name":"Plan 09","price":90,"score":91},{"id":"p10","name":"Plan 10","price":100,"score":90},{"id":"p11","name":"Plan 11","price":110,"score":89},{"id":"p12","name":"Plan 12","price":120,"score":88}]
root = Column(children=[intro,table])
intro = Text(text="Example data · compare twelve plans", variant="caption")
table = DataTable(data=options, rowKey="id", columns=[{"key":"name","label":"Plan"},{"key":"price","label":"Price","digits":2},{"key":"score","label":"Score"}], pageSize=10)
''',
  'S5': r'''ui 1 catalog "kelivo.native/1"
$company: boolean = false
$name: string = ""
$detail: string = "Retained company details"
root = Column(children=[intro,form,ask])
intro = Text(text="Example data · conditional invoice form", variant="caption")
form = Form(children=[toggle,nameInput,detailInput])
toggle = Switch(label="Company invoice", bind=$company)
nameInput = TextField(label="Name", bind=$name, required=true, maxLength=40)
detailInput = TextField(label="Company details", bind=$detail, required=true, visible=$company, multiline=true, maxLength=120)
ask = Button(label="Review invoice", form=form, action=Ask(text="Review these invoice details.", context={"name":$name,"company":$company,"detail":$detail}))
''',
  'S6': r'''ui 1 catalog "kelivo.native/1"
$slope: number = 1
$offset: number = 1
$useOffset: boolean = true
let intercept = $useOffset ? $offset : 0
let resultValue = $slope * 5 + intercept
let points = @sample(x => $slope * x + intercept, 0, 5, 6)
root = Column(children=[intro,form,result,chart,table,ask,reset])
intro = Text(text="Example data · linear model with local parameters", variant="caption")
form = Form(children=[slopeInput,toggle,offsetInput])
slopeInput = Slider(label="Slope", bind=$slope, min=-5, max=10, step=0.1)
toggle = Switch(label="Use intercept", bind=$useOffset)
offsetInput = NumberField(label="Intercept", bind=$offset, min=-10, max=10, step=0.5, visible=$useOffset)
result = Metric(label="Result at x=5", value=resultValue, unit="u", digits=1)
chart = Chart(kind="line", data=points, x="x", y=["y"], unit="u")
table = DataTable(data=points, rowKey="x", columns=[{"key":"x","label":"x"},{"key":"y","label":"y","digits":1}])
ask = Button(label="Explain parameters", form=form, action=Ask(text="Explain these parameters.", context={"slope":$slope,"offset":$offset,"useOffset":$useOffset,"result":resultValue}))
reset = Button(label="Reset model", action=Reset())
''',
};
