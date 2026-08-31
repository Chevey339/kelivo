
## Won't support functionalities
- `\href`
- `\includegraphics`
- `\lap` and other horizontal lapping command (This will probably be reconsidered in the future)
- `\mathchoice` and dependent features
- `\smash`
- `\overlinesegment`, `\underlinesegment`
- `\pmb`
- `\hspace*`
- Exotic composite symbols: `\Coloneqq, \coloneq, \Coloneq, \Eqqcolon, \Eqcolon, \colonapprox, \Colonapprox, \colonsim, \Colonsim, \simcolon, \simcoloncolon, \approxcolon, \approxcoloncolon`, and also their equivalent `\coloncolonequals` ...
- `\vcentcolon`
- `\textcircle` and related `\copyright`, `\registered`, etc.

## Functionalities that will be supported later
- `gather` environment
- `Vmatrix` environment
- `\mathnormal`

## Known parsing differences to KaTeX
- `\not` can only accept selected characters following it, because it is no longer backed by `\rlap`. (This will probably be revisited).
- The parsing behavior of `\overbrace` and `\underbase` with sub-sup pairs will be in line with MathJax rather than KaTeX.
- `\u2258` will be investigated later

## Known rendering differences to KaTeX
- Math functions with limit-like subscript and superscript will not adapt to sub/sup under/over styles under different styles. This breaks TeX spec. This is due to the design of AST, and is in accordance with UnicodeMath designs.
- Multiple `\hlines` and `||` column separators for matrices will not be supported, just as MathJax won't either.
- `aligned` and `alignedat` will have column spacings more similar to an ordinary equation. This should be an improvement to KaTeX and MathJax.
- `\genfrac`'s delimiters will have a larger spacing with inner node. (This might be fixed in future)
- `\color` commands inside a block will NOT be applied to right delimiters. This is in line with MathJax rather than KaTeX. 
- `\colon`'s behavior will be in line with MathJax rather than KaTeX.
- `\mathop` will no longer vertically center single characaters. MathJax doesn't do this either.
- `\cancel`, `\xcancel`, `\bcancel` will render differently compared to KaTeX. The vertical padding will be more similar to MathJaX.
- Due to the lack of `\mathchoice`, `\pod`, `\pmod`, `\mod` will have fixed spacing.
- `\dfrac`, `\tfrac` ... will have slight size deviation from KaTeX and will be in line with MathJax's rendering behavior. 
- `\sqrt` will no longer underflow below the baseline when given a child whose height is too small (e.g. `\sqrt{.}`). This is also different from MathJaX.
- The size of `\sqrt` symbol might be slightly different. Due to a different style choosing scheme.
- There will be no automatic thinspace between `\cdots` and right delimiter, (which is odd. MathJax and Tex don't have them either)


Any other deviations from KaTeX will be considered as bug.