# data — kelivo.native/1

`*` means required. Omitted optional values are absent unless a default is shown.
All nodes also accept: visible:boolean (default=true), enabled:boolean (default=true).

## Chart
Compare supplied data or sampled functions. Avoid fabricated factual series.
`Chart(data*:array, donut:boolean (default=false), kind*:string (oneOf=["line","area","bar","scatter","pie"]), title:string, unit:string, x*:string, xLabel:string, y*:array, yLabel:string)`

## DataTable
Inspect supplied records with local sorting/filtering. Avoid database-like editing.
`DataTable(columns*:array, data*:array, filterable:boolean (default=true), pageSize:number (default=10; oneOf=[10,20]; integer), rowKey*:string, sortable:boolean (default=true))`

Chart data is a record array; x names a nonempty field, y lists unique nonempty
field names. X values must be consistently strings or finite numbers; Y values
are finite numbers or null. For nonempty data, every y field must exist in at
least one record. Cartesian
charts allow 4 series and 2000 total
points; scatter requires numeric x. Pie uses one nonnegative y field, a positive
total and at most 12 items. Missing values remain gaps, never
zero; supply labels/units and follow the Skill's visible-provenance check. The app provides legends,
tooltips, data-table alternatives and accessible summaries.
DataTable accepts at most 1000 records and
1..8 columns, with a unique stable non-null scalar rowKey in each row.
All fields, including undisplayed fields, must be finite numbers, strings, booleans
or null. Remove or flatten nested records/arrays before passing data to the table.
Columns: {"key":"field","label":"Readable label","digits":2}; digits is optional,
integer 0..10. Column keys are unique/nonempty, labels nonblank, and each selected
field exists in at least one record when data is nonempty.
No cell expression or remote query. Sorting always places null values last.

