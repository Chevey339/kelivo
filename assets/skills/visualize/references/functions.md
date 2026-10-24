# Pure functions and actions

- `@abs(number) -> number`: Magnitude of a finite number.
- `@clamp(number, number, number) -> number`: Bound value between lower and upper; lower <= upper.
- `@cos(number) -> number`: Cosine in radians.
- `@formatNumber(number, number optional) -> string`: String display; optional digits defaults to 0, integer 0..10. No numeric coercion.
- `@max(number, number) -> number`: Larger of two finite numbers.
- `@min(number, number) -> number`: Smaller of two finite numbers.
- `@pow(number, number) -> number`: Finite real-valued power; invalid domains are errors.
- `@round(number, number optional) -> number`: Decimal rounding; optional digits defaults to 0, integer 0..10.
- `@sample(sampleBody, number, number, number) -> array`: Evaluate a pure scalar expression over an inclusive finite interval.
- `@sin(number) -> number`: Sine in radians.
- `@sqrt(number) -> number`: Square root of a nonnegative number.
`@sample(x => expression, start, end, count)` returns {"x":number,"y":number?}
records. start < end; count is an integer 2..501.
Endpoints are included. The body can read x, states and derived scalars; nested
sampling is prohibited. Domain errors produce null gaps, not zeros. This is
finite sampling, not symbolic solving or a general programming runtime.

`Ask(text*:string, context*:record)`
`Reset()`
Ask prepares a frozen editable draft and is never an automatic send. Reset restores source defaults locally.
