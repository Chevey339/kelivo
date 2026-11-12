# Test fonts

`JetBrainsMono-Regular.ttf` is an unmodified copy of the font previously
vendored in `dependencies/gpt_markdown/lib/fonts/`. Its name table identifies
JetBrains Mono 2.304 and the SIL Open Font License 1.1.

SHA-256: `a0bf60ef0f83c5ed4d7a75d45838548b1f6873372dfac88f71804491898d138f`.

The matching [upstream license](https://github.com/JetBrains/JetBrainsMono/blob/v2.304/OFL.txt)
is retained in `JetBrainsMono-OFL.txt`. These are test fixtures, not application
font assets. Keeping the bytes fixed preserves golden and benchmark metrics
when the old renderer package is removed.
