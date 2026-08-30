# Line Breaking

## Standard TeX Style vs. Advanced Display Style
This library plans to support two types of line breaking: standard TeX style and advanced display style.

Comparison between the two modes.

| Line Breaking        | Standard TeX Style                                                  | Advanced Display Style                               |
|----------------------|---------------------------------------------------------------------|------------------------------------------------------|
| Status               | Done                                                                | Planning                                             |
| Scenario             | In-line equations only                                              | Display equations only                               |
| Break Point Level    | Only the outermost level. E.g., not inside \left \right constructs. | Any nested node as long as in a single-line context  |
| Break Point Position | After `bin` and `rel` atoms                                         | Before `bin` atoms or after `rel` atoms.             |
| API Style            | Generate a list of broken-down widgets                              | A dedicated RenderObject subtype and layout protocol |

## Standard TeX Style Quick Start
 Currently you can try standard TeX-style line breaking through a very simplistic API:

```dart
final longEq = Math.tex(r'12345678\times 987654321 = 121932631112635269');
final breakResult = longEq.texBreak();
final widget = Wrap(
  children: breakResult.parts,
);
```
`Math.texBreak` will break the equation into pieces according to TeX spec **as much as possible** (some exceptions exist when `enforceNoBreak: true`). Then, you can assemble the pieces in whatever way you like. The most simple way is to put the parts inside a `Wrap`.

If you wish to implement a custom line breaking policy to manage the penalties, you can access the penalties in `BreakResult.penalties`. The values in `BreakResult.penalties` represent the line-breaking penalty generated at the right end of each `BreakResult.parts`. Note that `\nobreak` or `\penalty<number>=10000>` are left unbroken by default, you need to supply `enforceNoBreak: false` into `Math.texBreak` to expose those break points and their penalties.


## Background
TeX equation line breaking are documented in TeXBook Chapter 18.6. It reads
> When you have formulas in a paragraph, TEX may have to
break them between lines. ... A formula will be broken only after a relation symbol like = or < or →,
or after a binary operation symbol like + or − or ×, where the relation or binary
operation is on the “outer level” of the formula (i.e., not enclosed in {...} and
not part of an ‘\over’ construction).

From other popular equation editing software such as MS Word, we can see that the displayed equations can also be broken. The main difference is that it can line break inside arbitrarily deep nested nodes. Also it breaks before `bin` atoms rather than after.

However, the second style is very hard to achieve with current Flutter Math's design.

For example, the height of left/right delimiters depends on the highest element within the delimiters. In Flutter Math, it is decided that the height/width are calculated by Flutter's layout pipeline rather than precalculating them from AST. So each node has to be wrapped in one single RenderObject to share layout results, which requires a dedicated `RenderObject` subtype and a dedicated layout protocol.