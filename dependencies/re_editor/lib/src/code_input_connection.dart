part of 're_editor.dart';

/// Input transport independent of the renderer and its layout lifecycle.
typedef CodeInputConnectionFactory = CodeInputConnection Function(
  DeltaTextInputClient client, TextInputConfiguration configuration);

/// Owner callbacks retained only until accepted native work has drained.
/// The callbacks must not depend on the lifetime of the renderer or its line
/// controller. The document owner outlives the native close barrier.
class CodeDocumentCallbacks {
  const CodeDocumentCallbacks({this.onSubmitted, this.onContentInserted});
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<KeyboardInsertedContent>? onContentInserted;
}

abstract class CodeDocumentInputClient {
  CodeDocumentCallbacks captureDocumentCallbacks();
}

/// Resolves visual movement without mutating either document or selection.
abstract class CodeNavigationInputClient {
  CodeNavigationLayout? captureNavigationLayout();
  TextSelection resolveVerticalNavigation(TextSelection selection, bool up, bool extend);
}

abstract class CodeInputConnection {
  bool get attached;
  void setEditingState(TextEditingValue value);
  void updateConfig(TextInputConfiguration configuration);
  void setComposingRect(Rect rect);
  void setCaretRect(Rect rect);
  void setEditableSizeAndTransform(Size size, Matrix4 transform);
  void show();
  void close();
}

class _FlutterCodeInputConnection implements CodeInputConnection {
  _FlutterCodeInputConnection(DeltaTextInputClient client, TextInputConfiguration configuration)
      : connection = TextInput.attach(client, configuration);
  final TextInputConnection connection;
  @override bool get attached => connection.attached;
  @override void setEditingState(TextEditingValue value) => connection.setEditingState(value);
  @override void updateConfig(TextInputConfiguration configuration) => connection.updateConfig(configuration);
  @override void setComposingRect(Rect rect) => connection.setComposingRect(rect);
  @override void setCaretRect(Rect rect) => connection.setCaretRect(rect);
  @override void setEditableSizeAndTransform(Size size, Matrix4 transform) => connection.setEditableSizeAndTransform(size,transform);
  @override void show() => connection.show();
  @override void close() => connection.close();
}
