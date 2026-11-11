# inputs — kelivo.native/1

`*` means required. Omitted optional values are absent unless a default is shown.
All nodes also accept: visible:boolean (default=true), enabled:boolean (default=true).

## Button
Explicit Ask or Reset only. Avoid implying tool execution or automatic sending.
`Button(action*:Ask|Reset, form:FormId, label*:string, variant:string (default="tonal"; oneOf=["primary","tonal","plain"]))`

## Checkbox
Boolean confirmation; required=true requires checked. Avoid unrelated choice lists.
`Checkbox(bind*:$state<boolean>, label*:string, required:boolean (default=false))`

## Form
Group validation for associated buttons. Avoid nesting forms.
`Form(children*:[nodeId], title:string)`

## NumberField
Edit a finite number, optionally nullable. Avoid precision-critical accounting.
`NumberField(bind*:$state<number>?, label*:string, max:number, min:number, required:boolean (default=false), step:number (default=1), unit:string)`

## RadioGroup
Expose a small set of exclusive scalar choices. Avoid oversized lists.
`RadioGroup(bind*:$state<scalar>?, label*:string, options*:array, required:boolean (default=false))`

## Select
Choose a scalar option. Avoid unlabelled option values.
`Select(bind*:$state<scalar>?, label*:string, options*:array, placeholder:string, required:boolean (default=false))`

## Slider
Explore a bounded numeric range. Avoid unbounded or precise text entry.
`Slider(bind*:$state<number>, digits:number (min=0.0; max=10.0; integer), label*:string, max*:number, min*:number, step:number (default=1), unit:string)`

## Switch
Toggle one boolean immediately. Avoid using it for mutually exclusive choices.
`Switch(bind*:$state<boolean>, label*:string)`

## TextField
Edit a string with validation. Avoid treating a string as numeric input.
`TextField(bind*:$state<string>?, label*:string, maxLength:number (default=2000; min=1.0; max=8192.0; integer), minLength:number (min=0.0; max=8192.0; integer), multiline:boolean (default=false), placeholder:string, required:boolean (default=false))`

Options are records {"value":scalar,"label":"Readable label"}; values are unique
and match the bound state type. Form validates only currently visible descendants.
`Button(form=formId, action=Ask(...))` validates that Form before creating a draft;
include the Button in the root tree as well. Every control needs its own label.
Number min must not exceed max; Slider needs min < max. NumberField and Slider
both require step > 0.
TextField minLength must not exceed maxLength. Hidden input values are retained.

