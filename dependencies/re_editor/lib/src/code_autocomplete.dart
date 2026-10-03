part of 're_editor.dart';

/// Define code autocomplate prompt information.
///
/// See also [CodeKeywordPrompt], [CodeFieldPrompt] and [CodeFunctionPrompt].
abstract class CodePrompt {

  const CodePrompt({
    required this.word
  });

  /// Content associated with user input.
  ///
  /// e.g. User input is 're', the prompt word 'return' will be displayed to user.
  final String word;

  /// Get the final auto completion content. In most cases it is equal to [word], but there are some exceptions.
  /// For example, for functions, auto completion of parameters may be required.
  ///
  /// e.g. User input is 'he', 'hello(String name)' will be auto completed.
  CodeAutocompleteResult get autocomplete;

  /// Check whether the input meets this prompt condition.
  bool match(String input);

}

/// The keyword autocomplate prompt. such as 'return', 'class', 'new' and so on.
class CodeKeywordPrompt extends CodePrompt {

  const CodeKeywordPrompt({
    required super.word
  });

  @override
  CodeAutocompleteResult get autocomplete => CodeAutocompleteResult.fromWord(word);

  @override
  bool match(String input) {
    return word != input && word.startsWith(input);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is CodeKeywordPrompt && other.word == word;
  }

  @override
  int get hashCode => word.hashCode;

}

/// The field autocomplate prompt. Compared to [CodeKeywordPrompt],
/// type definitions also need to be provided.
///
/// If a line of code is 'String foo;', 'foo' is the word and 'String' is the type.
class CodeFieldPrompt extends CodePrompt {

  const CodeFieldPrompt({
    required super.word,
    required this.type,
    this.customAutocomplete,
  });

  /// The field type name.
  final String type;

  /// Will use custom autocomplete rather than word if this is not null.
  final CodeAutocompleteResult? customAutocomplete;

  @override
  CodeAutocompleteResult get autocomplete => customAutocomplete ?? CodeAutocompleteResult.fromWord(word);

  @override
  bool match(String input) {
    return word != input && word.startsWith(input);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is CodeFieldPrompt && other.word == word && other.type == type
      && other.customAutocomplete == customAutocomplete;
  }

  @override
  int get hashCode => Object.hash(word, type, customAutocomplete);

}

/// The function autocomplate prompt.
class CodeFunctionPrompt extends CodePrompt {

  const CodeFunctionPrompt({
    required super.word,
    required this.type,
    this.parameters = const {},
    this.optionalParameters = const {},
    this.customAutocomplete,
  });

  /// The function return type.
  final String type;

  /// The function required parameters.
  final Map<String, String> parameters;

  /// The function optional parameters.
  final Map<String, String> optionalParameters;

  /// Will use custom autocomplete rather than word if this is not null.
  final CodeAutocompleteResult? customAutocomplete;

  @override
  CodeAutocompleteResult get autocomplete => customAutocomplete ?? CodeAutocompleteResult.fromWord('$word(${parameters.keys.join(', ')})');

  @override
  bool match(String input) {
    return word != input && word.startsWith(input);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is CodeFunctionPrompt && other.word == word && other.type == type &&
      mapEquals(other.parameters, parameters) && mapEquals(other.optionalParameters, optionalParameters)
      && other.customAutocomplete == customAutocomplete;
  }

  @override
  int get hashCode => Object.hash(word, type, parameters, optionalParameters, customAutocomplete);

}

/// The autocomplete result selected by user, the editor will apply this
/// to code content.
class CodeAutocompleteResult {

  const CodeAutocompleteResult({
    required this.input,
    required this.word,
    required this.selection
  });

  factory CodeAutocompleteResult.fromWord(String word) {
    return CodeAutocompleteResult(
      input: '',
      word: word,
      selection: TextSelection.collapsed(
        offset: word.length
      )
    );
  }

  /// The autocomplete text.
  /// e.g.
  /// If user inputs `go` and the word is `good`, we will replace `go` with `good`.
  final String input;
  final String word;

  /// The new selection after the autocompletion.
  final TextSelection selection;

}

/// The current user input and prompts for editing a run of text.
class CodeAutocompleteEditingValue {

  const CodeAutocompleteEditingValue({
    required this.input,
    required this.prompts,
    required this.index,
  });

  /// User input content.
  final String input;

  /// Matched code prompts.
  final List<CodePrompt> prompts;

  /// Current selected code prompt.
  final int index;

  CodeAutocompleteEditingValue copyWith({
    String? input,
    List<CodePrompt>? prompts,
    int? index,
  }) {
    return CodeAutocompleteEditingValue(
      input: input ?? this.input,
      prompts: prompts ?? this.prompts,
      index: index ?? this.index,
    );
  }

  CodeAutocompleteResult get autocomplete {
    final CodeAutocompleteResult result = prompts[index].autocomplete;
    if (result.word.isEmpty) {
      return result;
    }
    final TextSelection finalSelection = result.selection.copyWith(
      baseOffset: result.selection.baseOffset - input.length,
      extentOffset: result.selection.extentOffset - input.length,
    );
    return CodeAutocompleteResult(
      input: input,
      word: result.word,
      selection: finalSelection,
    );
  }

}

/// Builds the overlay autocomplete prompts view.
typedef CodeAutocompleteWidgetBuilder = PreferredSizeWidget Function(
  BuildContext context,
  ValueNotifier<CodeAutocompleteEditingValue> notifier,
  ValueChanged<CodeAutocompleteResult> onSelected
);

/// The autocomplete prompts builder.
abstract class CodeAutocompletePromptsBuilder {

  /// Build the prompts with the current code.
  CodeAutocompleteEditingValue? build(
    BuildContext context,
    CodeLine codeLine,
    CodeLineSelection selection,
  );

}

/// The default autocomplete prompts builder.
abstract class DefaultCodeAutocompletePromptsBuilder implements CodeAutocompletePromptsBuilder {

  /// Constructs the builder with defined prompts.
  factory DefaultCodeAutocompletePromptsBuilder({
    Mode? language,
    List<CodeKeywordPrompt> keywordPrompts = const [],
    List<CodePrompt> directPrompts = const [],
    Map<String, List<CodePrompt>> relatedPrompts = const {},
  }) => _DefaultCodeAutocompletePromptsBuilder(
    language: language,
    keywordPrompts: keywordPrompts,
    directPrompts: directPrompts,
    relatedPrompts: relatedPrompts,
  );

}

/// A widget enables code autocomplete for [CodeEditor].
///
/// Developers can customize the view styles and prompt logic they need.
///
/// The following is a common usage.
///
/// ```
/// CodeAutocomplete(
///   viewBuilder: (context, notifier, onSelected) {
///     // TODO build the options list widget.
///   },
///   promptsBuilder: DefaultCodeAutocompletePromptsBuilder(
///     language: langDart,
///     directPrompts: [
///       CodeFieldPrompt(
///         word: 'foo',
///         type: 'String'
///       ),
///       CodeFunctionPrompt(
///         word: 'hello',
///         type: 'void',
///         parameters: {
///           'value': 'String',
///         }
///       )
///     ],
///   ),
///   child: CodeEditor()
/// )
/// ```
class CodeAutocomplete extends StatelessWidget {

  const CodeAutocomplete({
    super.key,
    required this.viewBuilder,
    required this.promptsBuilder,
    required this.child,
  });

  final CodeAutocompleteWidgetBuilder viewBuilder;
  final CodeAutocompletePromptsBuilder promptsBuilder;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return _CodeAutocomplete(
      viewBuilder: viewBuilder,
      promptsBuilder: promptsBuilder,
      child: child
    );
  }

}