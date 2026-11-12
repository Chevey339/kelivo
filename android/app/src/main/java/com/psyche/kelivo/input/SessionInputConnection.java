package com.psyche.kelivo.input;

import android.text.Editable;
import android.view.KeyEvent;
import android.view.View;
import android.view.inputmethod.BaseInputConnection;
import android.view.inputmethod.InputConnectionWrapper;

/** Each IME attachment has its own lifetime; the document outlives restarts. */
final class SessionInputConnection extends InputConnectionWrapper {
  final MirrorConnection document;
  final View view;
  boolean closed;
  int batchDepth;
  SessionInputConnection(View view, MirrorConnection document) {
    super(document, true);
    this.document = document;
    this.view = view;
    document.inputHandles.add(this);
  }
  @Override public boolean beginBatchEdit() {
    if (closed || !document.beginBatchEdit()) return false;
    batchDepth++;
    return true;
  }
  @Override public boolean endBatchEdit() {
    if (closed || batchDepth == 0) return false;
    batchDepth--;
    document.endBatchEdit();
    return batchDepth > 0;
  }
  @Override public void closeConnection() {
    if (closed) return;
    closed = true;
    document.inputHandles.remove(this);
    // These operations join the same navigation queue as accepted edits.
    // Balance only this handle's external batches; other handles may exist.
    document.finishComposingText();
    while (batchDepth > 0) { batchDepth--; document.endBatchEdit(); }
    setTarget(new BaseInputConnection(view, false) {
      @Override public Editable getEditable() { return null; }
      @Override public boolean sendKeyEvent(KeyEvent event) { return false; }
    });
  }
}
