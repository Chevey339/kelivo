# v0.2.0 Migration Guide

## Name Changes
| Old name   | New name          |
|------------|-------------------|
| Options    | MathOptions       |
| Settings   | TexParserSettings |
| SizeMode   | MathSize          |
| ParseError | ParseException    |

## New Widget Variant
The `FlutterMath` class has been deprecated and becomes a wrapper of `Math` widget. You should use more specific widget variants: `Math` and `SelectableMath`.

`Math` is static, non-selectable. `SelectableMath` is static but selectable. If you wish to avoid extra performance cost brings by selectibility, use `Math`.

The constructor name has also been changed to `Math.tex` and `SelectableMath.tex`.

## TextStyle over Options
`TextStyle` will be adopted as the parameter in exposed APIs to replace `Options`. Directly supplying `Options` is OK, but is apparently not the best way. 

### Use TextStyle to controll the size of your equation 
1. `TextStyle.fontSize` will be the size of any math symbols.
2. `logicalPpi` will be used to decide the size of absolute units (pt, cm, inch, etc). 
3. If `logicalPpi` is null, then absolute units will resize on different `TextStyle.fontSize` to keep a consistent ratio (Just like current `baseSizeMultiplier`'s behavior). 
4. `baseSizeMultiplier` is deprecated. If you still wish similar behavior, calculate relevant parameters from `MathOptions.defaultFontSize` and `double defaultLogicalPpi(double fontSize)`.
5. If neither `TextStyle.fontSize` nor `logicalPpi` is supplied, then the widget will use the default `TextStyle` supplied by Flutter's build context.

## Sanitized Error System
`ParseError` will be renamed to `ParseException`. Also, other throws within the library will be sanitized to throw either `ParseException`, `BuildException`, `EncodeExecption`. All of them extends `FlutterMathException`. As a result, `onErrorFallback` will have a different signature and allows users to handle exceptions with type safety.

Detailed exception variant can be found in their respective API documentations.

The final API will look like
```
Math.tex(
  r'\frac a b',
  textStyle: TextStyle(fontSize: 42),
  // settings: TexParserSettings(),
  // logicalPpi: defaultLogicalPpi(42),
  onErrorFallback: (err) => {
    if (error is ParseException)
      return SelectableText('ParseError: ${err.message}');
    return Container(
      color: Colors.red,
      SelectableText(err.toString());
    )
  },
)
```