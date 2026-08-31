# Design Rationale

## Priority of design
1. Consistent editing logic
2. Faithful rendering of additional features if not conflicting with editing logic.
3. Fast re-rendering on editing
4. Good layout on constrained screen sizes
5. Simple and declarative code
6. Fast parsing and rendering

## AST

The AST of this project has a very similar structure compared with MathML, the AST of MathJax, with several differences:

- MultiscriptNode do not support extra pairs of postscripts as <mmultiscripts> in MathML does. Extra postscript pairs will conflict with UnicodeMath input syntax. 
- <msubsup> and part of <mmultiscripts> are merged into one single MultiscriptsNode. After removing the support of extra postscript feature, they become largely the same. In current TeX height/depth calculation mechanism, nesting subsups with presubscripts will fail to generate vertically-aligned scripts. We have to merge it into one node anyway.


### Rosyln's Reg-Green Tree
The AST uses Roslyn's immutable Red-Green Tree (without deduplication features) to construct the AST. And the GreenNodes are completely stateless and context-free.
- In the build process, this ensures a uni-directional data flow. Options down, widgets up.
- It is simpler to perform widget reusing. As long as the GreenNode and relevant Options stay the same, the entire subtree can be bypassed. And this simple mechanism will cover ALL possible widget reusing scenarios, as the flutter widget tree itself is immutable as well.
- It is tremendously easier and more robust to revert any editing changes. You just need to find the old root node.
- Any layout parameters can be safely calculated and stored inside AST nodes.


### Text and Math mode AST design Rationale:
We merge text-mode symbols and math-mode symbols into a single SymbolNode class but separated by their AtomTypes at the parsing time. This distinction of symbols will be preserved throughout any editing. We did not choose the following alternatives:
- Make a TextNode extend from EquationRowNode and only allow this type to hold TextSymbolNode as children
    - Good for editing experience
    - Horrible nesting of math inside text inside math while editing (which KaTeX supports). Type safety concerns for TextSymbolNode's occurance.
    - We could straightfoward avoid math inside text during parsing. But it requires a complete re-write of the parser.
- Make a TextNode same as before, but adding a property in Options to change the behavior of child MathSymbolNode
    - Similar as before without type safety concern. However a symbol will behave vastly different in two modes. Some lazy initialization become impossible and inefficient.
- Add a property in Options, and using a StyleNode to express mode changes
    - Similar to above option. This StyleNode will require extra caution during AST optimization due to its property and all the text style commands beneath it.
- Use a tree of TextNode inspired by TextSpan
    - How can I nest math inside text?



## Rendering
- Tex's height and depth calculations are performed implicitly by the layout process of RenderObjects. The height and depth information is carried by MathOrd widget and propagated during widget composition. I feel this is better and simpler than using widget-layer parameters to override existing everyday render-layer behaviors.
- Other Tex's font specs are calculated inside AST nodes and passed explicitly into dedicated layout widgets. Incorporating them (e.g. italic) into RenderObject will cause heavy compatibility burdens (as the breakable RenderObject has already caused) with no real benefits, since the AST is already efficient at calculating and reusing these parameters.
- (WIP) Breakable RenderObjects are made subclasses of RenderBox, which caused huge amount of boilerplate code and exception spots. But we have no choice since we need the interop between RenderBox and breakable ones.
- A large amount of layouts are expressed by custom IntrinsicLayoutDelegate. This is due to the observation that most math nodes will disregard constraints during layout, and its horizontal resizing does not influence vertical layout, and vice versa. IntrinsicLayoutDelegate is hugely concise and efficient in this scenario.


## Symbols and Font
KaTeX use mode (math/text) to directly map commands depending on context into different replacement atoms + atom types + font family. The atom will first try to use explicit contextual font. If not available, it will fall back to default font provided by atom type and font family. (With the exception of wide chars)

Due to the need of editing and copy/pasting, we need to maintain an independent, Unicode-based character set as AST symbols. We chose a method similar to MathJax. Unicode char + variantForm uniquely define a symbol. Each symbol has its default replacement, types and font settings, but they can only be overrided when they are constructed by the compiler. Likewise, the symbol will first try to use explicit contextual font. If not available, it will fall back. Any chars using a replacement will never be able to override their font family. (with some exceptions on some punctuations which KaTeX choose to use replacement).

variantForm is basically chosen in line with MathJax, for the exception of \u210F(\hbar).