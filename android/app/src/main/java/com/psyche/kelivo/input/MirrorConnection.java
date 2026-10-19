package com.psyche.kelivo.input;

import android.content.ClipData;
import android.content.ClipDescription;
import android.view.inputmethod.EditorInfo;
import androidx.core.view.inputmethod.InputContentInfoCompat;
import androidx.core.view.inputmethod.InputConnectionCompat;
import java.io.ByteArrayOutputStream;
import java.io.InputStream;
import android.content.ClipboardManager;
import android.content.Context;
import android.os.Build;
import android.text.Editable;
import android.text.Selection;
import android.text.SpannableStringBuilder;
import android.text.method.TextKeyListener;
import android.view.KeyEvent;
import android.view.View;
import android.view.inputmethod.BaseInputConnection;
import android.view.inputmethod.ExtractedText;
import android.view.inputmethod.ExtractedTextRequest;
import android.view.inputmethod.SurroundingText;
import android.view.inputmethod.TextAttribute;
import java.util.ArrayList;
import java.util.ArrayDeque;
import java.util.HashSet;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.function.BooleanSupplier;
import java.util.function.Consumer;

/** Experimental Android authority: full Editable, sparse ordered events. */
public final class MirrorConnection extends BaseInputConnection {
  static final int QUERY_LIMIT = 2048;
  final View view;
  final String session;
  final MirrorEditable text;
  final Consumer<Map<String, Object>> sink;
  long revision;
  Long pendingAppRequest;
  String pendingAffinity;
  Consumer<Map<String,Object>> navigationSink;
  Consumer<Map<String,Object>> interactionSink;
  Runnable selectionSink;
  boolean selectionDirty;
  String enterMode = "newline";
  final HashSet<String> ownerCommands = new HashSet<>();

  void ownerCommand(String command, Long request) {
    executeOrQueue(() -> {
      forcePublish();
      Map<String,Object> event=new HashMap<>();
      event.put("session",session);event.put("type","command");event.put("command",command);
      if(request!=null)event.put("request",request);
      interactionSink.accept(event);
    });
  }
  String[] mimeTypes = new String[0];
  android.icu.text.BreakIterator characterBreaks;
  final ArrayDeque<Runnable> deferred = new ArrayDeque<>();
  boolean navigationPending;
  String navigationError;
  long navigationSerial;
  int requestedBatchDepth;
  int depth;
  boolean valid = true;
  boolean closeRequested;
  int acceptedDepth;
  final HashSet<SessionInputConnection> inputHandles = new HashSet<>();
  final ArrayList<Consumer<Long>> closeCallbacks = new ArrayList<>();
  boolean initialized;
  int lastBase, lastExtent, lastComposingStart, lastComposingEnd;

  public MirrorConnection(View view, String session, String initial, int base, int extent,
                          Consumer<Map<String, Object>> sink) {
    super(view, true);
    this.view = view;
    this.session = session;
    this.sink = sink;
    text = new MirrorEditable();
    text.append(initial);
    Selection.setSelection(text, base, extent);
    text.patches.clear();
    remember();
    initialized = true;
  }

  @Override public Editable getEditable() { return text; }
  int base() { return Selection.getSelectionStart(text); }
  int extent() { return Selection.getSelectionEnd(text); }
  int composingStart() { return getComposingSpanStart(text); }
  int composingEnd() { return getComposingSpanEnd(text); }
  void remember() {
    lastBase = base(); lastExtent = extent();
    lastComposingStart = composingStart(); lastComposingEnd = composingEnd();
  }

  boolean canAccept() { return valid && (!closeRequested || acceptedDepth > 0); }
  void runAccepted(Runnable operation) {
    acceptedDepth++;
    try { operation.run(); } finally { acceptedDepth--; }
  }
  void executeOrQueue(Runnable operation) {
    if (!canAccept()) return;
    if (navigationPending) deferred.addLast(operation);
    else runAccepted(operation);
  }
  @Override public boolean beginBatchEdit() {
    if (!canAccept()) return false;
    requestedBatchDepth++;
    executeOrQueue(() -> depth++);
    return true;
  }
  @Override public boolean endBatchEdit() {
    if (!canAccept() || requestedBatchDepth == 0) return false;
    requestedBatchDepth--;
    executeOrQueue(() -> { depth--; if (depth == 0) flush(); });
    return requestedBatchDepth > 0;
  }
  boolean batch(BooleanSupplier operation) {
    depth++; acceptedDepth++;
    try { return operation.getAsBoolean(); }
    finally { acceptedDepth--; depth--; if (depth == 0) flush(); }
  }
  boolean edit(BooleanSupplier operation) {
    if (!canAccept()) return false;
    if (navigationPending) {
      deferred.addLast(() -> batch(operation));
      return true;
    }
    return batch(operation);
  }
  void requestNavigation(boolean up, boolean extend) {
    requestNavigation(up,extend,false);
  }
  void requestNavigation(boolean up, boolean extend, boolean lineEdge) {
    executeOrQueue(() -> {
      // Navigation is an asynchronous ordering barrier, including inside an
      // IME batch. Publish preceding edits so Flutter lays out this revision.
      forcePublish();
      navigationPending = true;
      Map<String,Object> request = new HashMap<>();
      request.put("session",session); request.put("revision",revision);
      request.put("serial",++navigationSerial);
      request.put("base",base()); request.put("extent",extent());
      request.put("up",up); request.put("extend",extend);
      request.put("lineEdge",lineEdge);
      navigationSink.accept(request);
    });
  }
  void completeNavigation(long serial, int start, int end) { completeNavigation(serial,start,end,null); }
  void completeNavigation(long serial, int start, int end, String affinity) {
    if (!valid || !navigationPending || serial != navigationSerial) return;
    if (start < 0 || end < 0 || start > text.length() || end > text.length())
      throw new IllegalArgumentException("Invalid navigation target");
    navigationPending = false;
    navigationError = null;
    pendingAffinity = affinity;
    batch(() -> {
      Selection.setSelection(text,start,end);
      return true;
    });
    forcePublish();
    while (!navigationPending && valid && !deferred.isEmpty()) runAccepted(deferred.removeFirst());
  }
  void flush() {
    publish(false);
  }
  void publish(boolean force) {
    if (!initialized || !valid || (!force && depth != 0)) return;
    if (pendingAppRequest == null && pendingAffinity == null && text.patches.isEmpty() && lastBase == base() && lastExtent == extent()
        && lastComposingStart == composingStart() && lastComposingEnd == composingEnd()) {
      notifySelection();
      return;
    }
    Map<String, Object> event = new HashMap<>();
    event.put("session", session);
    event.put("from", revision);
    event.put("to", ++revision);
    event.put("patches", new ArrayList<>(text.patches));
    event.put("selection", List.of(base(), extent()));
    event.put("composing", List.of(composingStart(), composingEnd()));
    text.patches.clear();
    if (pendingAppRequest != null) {
      event.put("appRequest", pendingAppRequest);
      pendingAppRequest = null;
    }
    if(pendingAffinity != null) { event.put("affinity",pendingAffinity); pendingAffinity=null; }
    remember();
    sink.accept(event);
    selectionDirty = true;
    notifySelection();
  }
  void notifySelection() {
    // Dart may need an intermediate revision to resolve layout or a flush
    // barrier. The IME must still see only the completed outer batch. `depth`
    // counts applied operations; accepted endBatch calls may still be queued.
    if (depth != 0 || !selectionDirty) return;
    selectionDirty = false;
    if (selectionSink != null) selectionSink.run();
  }

  @Override public boolean commitText(CharSequence value, int cursor) {
    return edit(() -> super.commitText(value, cursor));
  }
  @Override public boolean replaceText(int start, int end, CharSequence value, int cursor, TextAttribute attributes) {
    return edit(() -> super.replaceText(start,end,value,cursor,attributes));
  }
  @Override public boolean setComposingText(CharSequence value, int cursor) {
    return edit(() -> super.setComposingText(value, cursor));
  }
  @Override public boolean setComposingRegion(int start, int end) {
    return edit(() -> super.setComposingRegion(start, end));
  }
  @Override public boolean finishComposingText() {
    return edit(() -> super.finishComposingText());
  }
  @Override public boolean setSelection(int start, int end) {
    return edit(() -> start >= 0 && end >= 0 && start <= text.length() && end <= text.length()
      && super.setSelection(start, end));
  }
  @Override public boolean deleteSurroundingText(int before, int after) {
    return edit(() -> super.deleteSurroundingText(before, after));
  }
  @Override public boolean deleteSurroundingTextInCodePoints(int before, int after) {
    return edit(() -> super.deleteSurroundingTextInCodePoints(before, after));
  }
  void retireInputHandles() {
    for(SessionInputConnection handle:new ArrayList<>(inputHandles)) handle.closeConnection();
  }

  void closeWhenDrained(Consumer<Long> completed) {
    if (!valid) { completed.accept(revision); return; }
    closeCallbacks.add(completed);
    if (closeRequested) return;
    retireInputHandles();
    closeRequested = true;
    Runnable finish = () -> {
      // Only after all accepted operations have run is it safe to end any
      // unclosed document-level batch and publish its final state.
      depth = 0; requestedBatchDepth = 0;
      batch(() -> super.finishComposingText());
      forcePublish();
      valid = false;
      for(Consumer<Long> callback:new ArrayList<>(closeCallbacks)) callback.accept(revision);
      closeCallbacks.clear();
    };
    if (navigationPending) deferred.addLast(finish);
    else runAccepted(finish);
  }

  @Override public void closeConnection() { closeWhenDrained(revision -> {}); }

  @Override public boolean performEditorAction(int action) {
    if (!canAccept()) return false;
    if (action == EditorInfo.IME_ACTION_NONE) return commitText("\n",1);
    if (interactionSink == null) return false;
    executeOrQueue(() -> {
      forcePublish();
      interactionSink.accept(Map.of("session",session,"type","action","action",action));
    });
    return true;
  }

  boolean insertContent(InputContentInfoCompat content, int flags) {
    if (!canAccept() || interactionSink == null) return false;
    String matched=null;
    for(int i=0;i<content.getDescription().getMimeTypeCount() && matched==null;i++) {
      String type=content.getDescription().getMimeType(i);
      for(String allowed:mimeTypes) if(ClipDescription.compareMimeTypes(type,allowed)) { matched=type;break; }
    }
    if(matched==null)return false;
    boolean permission=(flags & InputConnectionCompat.INPUT_CONTENT_GRANT_READ_URI_PERMISSION)!=0;
    byte[] bytes;
    boolean acquired=false;
    try {
      if(permission) { content.requestPermission(); acquired=true; }
      try(InputStream input=view.getContext().getContentResolver().openInputStream(content.getContentUri());
          ByteArrayOutputStream output=new ByteArrayOutputStream()) {
        if(input==null)return false;
        byte[] buffer=new byte[65536];int count;
        while((count=input.read(buffer))!=-1)output.write(buffer,0,count);
        bytes=output.toByteArray();
      }
    } catch(Exception error) { return false; }
    finally { if(acquired)content.releasePermission(); }
    final String mime=matched;
    executeOrQueue(() -> {
      forcePublish();
      interactionSink.accept(Map.of("session",session,"type","content","mimeType",mime,
        "uri",content.getContentUri().toString(),"data",bytes));
    });
    return true;
  }

  @Override public boolean performContextMenuAction(int id) {
    return edit(() -> {
      int left = Math.min(base(), extent()), right = Math.max(base(), extent());
      ClipboardManager clipboard = (ClipboardManager)view.getContext().getSystemService(Context.CLIPBOARD_SERVICE);
      if (id == android.R.id.selectAll) return setSelection(0, text.length());
      if (id == android.R.id.cut || id == android.R.id.copy) {
        if (left == right) return true;
        // Do not delete unless the Android clipboard service accepted the data.
        // In particular, a Binder size failure must never become data loss.
        try {
          clipboard.setPrimaryClip(ClipData.newPlainText("text", text.subSequence(left, right).toString()));
        } catch (RuntimeException error) {
          android.util.Log.w("MirrorIme", "Clipboard rejected selection; text retained", error);
          return false;
        }
        if (id == android.R.id.cut) {
          removeComposingSpans(text);
          text.delete(left, right);
          Selection.setSelection(text, left);
        }
        return true;
      }
      if (id == android.R.id.paste) {
        ClipData clip = clipboard.getPrimaryClip();
        if (clip == null || clip.getItemCount() == 0) return false;
        CharSequence value = clip.getItemAt(0).coerceToText(view.getContext());
        if (value == null) return false;
        removeComposingSpans(text);
        text.replace(left, right, value);
        Selection.setSelection(text, left + value.length());
        return true;
      }
      return false;
    });
  }

  int adjacentCharacter(int position, boolean forward) {
    if(characterBreaks==null)characterBreaks=android.icu.text.BreakIterator.getCharacterInstance();
    characterBreaks.setText(new CharSequenceCharacterIterator(text,0,text.length()));
    int next=forward?characterBreaks.following(position):characterBreaks.preceding(position);
    return next==android.icu.text.BreakIterator.DONE?position:next;
  }

  @Override public boolean sendKeyEvent(KeyEvent event) {
    if (!canAccept()) return false;
    int code = event.getKeyCode();
    boolean modifier=event.isCtrlPressed()||event.isMetaPressed();
    String command=code==KeyEvent.KEYCODE_ESCAPE?"escape":modifier&&code==KeyEvent.KEYCODE_V?"paste":
      modifier&&code==KeyEvent.KEYCODE_Z?(event.isShiftPressed()?"redo":"undo"):null;
    if(command!=null&&ownerCommands.contains(command)) {
      if(event.getAction()==KeyEvent.ACTION_DOWN&&event.getRepeatCount()==0)ownerCommand(command,null);
      return true;
    }
    if(code==KeyEvent.KEYCODE_ENTER||code==KeyEvent.KEYCODE_NUMPAD_ENTER) {
      if(event.getAction()!=KeyEvent.ACTION_DOWN)return true;
      executeOrQueue(()->{
        if(event.getRepeatCount()!=0&&!enterMode.equals("newline"))return;
        boolean composing=composingStart()>=0&&composingEnd()>composingStart();
        boolean send=enterMode.equals("controlSend")?modifier:enterMode.equals("send")&&!modifier&&!event.isShiftPressed();
        if(send&&!composing)performEditorAction(EditorInfo.IME_ACTION_SEND);
        else batch(()->TextKeyListener.getInstance().onKeyDown(view,text,code,event));
      });
      return true;
    }
    boolean navigation = code == KeyEvent.KEYCODE_DPAD_UP || code == KeyEvent.KEYCODE_DPAD_DOWN
      || code == KeyEvent.KEYCODE_DPAD_LEFT || code == KeyEvent.KEYCODE_DPAD_RIGHT
      || code == KeyEvent.KEYCODE_MOVE_HOME || code == KeyEvent.KEYCODE_MOVE_END;
    boolean editing = code == KeyEvent.KEYCODE_DEL || code == KeyEvent.KEYCODE_FORWARD_DEL;
    boolean shortcut = modifier && (code == KeyEvent.KEYCODE_A
      || code == KeyEvent.KEYCODE_C || code == KeyEvent.KEYCODE_X || code == KeyEvent.KEYCODE_V);
    if (!navigation && !editing && !shortcut && event.getUnicodeChar() == 0
      && !KeyEvent.isModifierKey(code)) return false;
    if (code == KeyEvent.KEYCODE_DEL || code == KeyEvent.KEYCODE_FORWARD_DEL) {
      if (event.getAction() != KeyEvent.ACTION_DOWN) return true;
      return edit(() -> TextKeyListener.getInstance().onKeyDown(view, text, code, event));
    }
    if(KeyEvent.isModifierKey(code)) {
      return edit(() -> event.getAction()==KeyEvent.ACTION_DOWN
        ? TextKeyListener.getInstance().onKeyDown(view,text,code,event)
        : TextKeyListener.getInstance().onKeyUp(view,text,code,event));
    }
    if (event.getAction() != KeyEvent.ACTION_DOWN) return true;
    if ((code == KeyEvent.KEYCODE_MOVE_HOME || code == KeyEvent.KEYCODE_MOVE_END) && !modifier) {
      if (navigationSink == null) return false;
      requestNavigation(code == KeyEvent.KEYCODE_MOVE_HOME,event.isShiftPressed(),true);
      return true;
    }
    if (code == KeyEvent.KEYCODE_DPAD_UP || code == KeyEvent.KEYCODE_DPAD_DOWN) {
      if (navigationSink == null) return false;
      requestNavigation(code == KeyEvent.KEYCODE_DPAD_UP, event.isShiftPressed());
      return true;
    }
    if (modifier) {
      if (code == KeyEvent.KEYCODE_A) return performContextMenuAction(android.R.id.selectAll);
      if (code == KeyEvent.KEYCODE_X) return performContextMenuAction(android.R.id.cut);
      if (code == KeyEvent.KEYCODE_C) return performContextMenuAction(android.R.id.copy);
      if (code == KeyEvent.KEYCODE_V) return performContextMenuAction(android.R.id.paste);
    }
    if (code == KeyEvent.KEYCODE_DPAD_LEFT || code == KeyEvent.KEYCODE_DPAD_RIGHT
        || code == KeyEvent.KEYCODE_MOVE_HOME || code == KeyEvent.KEYCODE_MOVE_END) {
      return edit(() -> {
      int target = extent();
      if (code == KeyEvent.KEYCODE_MOVE_HOME) target = 0;
      else if (code == KeyEvent.KEYCODE_MOVE_END) target = text.length();
      else if(!event.isShiftPressed() && base()!=extent()) target=code==KeyEvent.KEYCODE_DPAD_LEFT?Math.min(base(),extent()):Math.max(base(),extent());
      else if (code == KeyEvent.KEYCODE_DPAD_LEFT && target > 0) target = adjacentCharacter(target, false);
      else if (code == KeyEvent.KEYCODE_DPAD_RIGHT && target < text.length()) target = adjacentCharacter(target, true);
      return setSelection(event.isShiftPressed() ? base() : target, target);
      });
    }
    return edit(() -> TextKeyListener.getInstance().onKeyDown(view, text, code, event));
  }

  // Query bounds are distinct from document bounds. Never return a silently
  // truncated selected string: a keyboard might copy it as if it were complete.
  @Override public CharSequence getTextBeforeCursor(int n, int flags) {
    if (navigationPending) return null;
    return super.getTextBeforeCursor(Math.min(Math.max(n, 0), QUERY_LIMIT), flags);
  }
  @Override public CharSequence getTextAfterCursor(int n, int flags) {
    if (navigationPending) return null;
    return super.getTextAfterCursor(Math.min(Math.max(n, 0), QUERY_LIMIT), flags);
  }
  @Override public CharSequence getSelectedText(int flags) {
    if (navigationPending || Math.abs(extent() - base()) > QUERY_LIMIT) return null;
    return super.getSelectedText(flags);
  }
  @Override public SurroundingText getSurroundingText(int before, int after, int flags) {
    if (navigationPending || Math.abs(extent() - base()) > QUERY_LIMIT) return null;
    return super.getSurroundingText(Math.min(before, QUERY_LIMIT), Math.min(after, QUERY_LIMIT), flags);
  }
  @Override public ExtractedText getExtractedText(ExtractedTextRequest request, int flags) {
    // A bounded snapshot cannot promise continuous extraction: an expanded
    // selection can later exceed that bound. Explicitly decline monitoring
    // instead of accepting a token whose contents would silently go stale.
    if (navigationPending || (flags & GET_EXTRACTED_TEXT_MONITOR) != 0) return null;
    int left = Math.min(base(), extent()), right = Math.max(base(), extent());
    if (right - left > QUERY_LIMIT) return null;
    int start = Math.max(0, left - QUERY_LIMIT / 2);
    int end = Math.min(text.length(), Math.max(right, start + QUERY_LIMIT));
    ExtractedText result = new ExtractedText();
    result.text = text.subSequence(start, end).toString();
    result.startOffset = start;
    result.partialStartOffset = -1;
    result.partialEndOffset = -1;
    result.selectionStart = base() - start;
    result.selectionEnd = extent() - start;
    return result;
  }

  void forcePublish() {
    publish(true);
  }

  void applyAppEdit(long from, long request, List<List<Object>> patches,
      int start, int end, int composingStart, int composingEnd,
      Consumer<Map<String,Object>> completed, Consumer<Exception> failed) {
    if (!canAccept()) { failed.accept(new IllegalStateException("Document is closing")); return; }
    executeOrQueue(() -> {
      try {
      // An IME may keep an outer batch open. Publish edits preceding this app
      // command before checking its base revision, without ending that batch.
      forcePublish();
      if (from != revision) {
        completed.accept(Map.of("applied",false,"revision",revision));
        return;
      }
      int length=text.length();
      for(List<Object> patch:patches) {
        int left=((Number)patch.get(0)).intValue(),right=((Number)patch.get(1)).intValue();
        if(left<0||right<left||right>length)throw new IllegalArgumentException("App patch outside document");
        length+=((String)patch.get(2)).length()-(right-left);
      }
      if(start<0||end<0||start>length||end>length)throw new IllegalArgumentException("App selection outside document");
      if((composingStart!=-1||composingEnd!=-1)&&(composingStart<0||composingEnd<composingStart||composingEnd>length))
        throw new IllegalArgumentException("App composing outside document");
      batch(() -> {
        removeComposingSpans(text);
        for(List<Object> patch:patches) text.replace(((Number)patch.get(0)).intValue(),((Number)patch.get(1)).intValue(),(String)patch.get(2));
        Selection.setSelection(text,start,end);
        if(composingStart>=0&&composingEnd>composingStart)super.setComposingRegion(composingStart,composingEnd);
        pendingAppRequest=request;
        return true;
      });
      forcePublish();
      completed.accept(Map.of("applied",true,"revision",revision));
      } catch (Exception error) { failed.accept(error); }
    });
  }

  final class MirrorEditable extends SpannableStringBuilder {
    final ArrayList<List<Object>> patches = new ArrayList<>();
    @Override public SpannableStringBuilder replace(int start, int end, CharSequence source, int a, int b) {
      depth++;
      String inserted = source.subSequence(a, b).toString();
      boolean changed = end - start != inserted.length();
      for (int i = 0; !changed && i < inserted.length(); i++) changed = charAt(start + i) != inserted.charAt(i);
      try {
        super.replace(start, end, source, a, b);
        if (changed && patches != null) patches.add(List.of(start, end, inserted));
        return this;
      } finally { depth--; if (depth == 0) flush(); }
    }
    @Override public void setSpan(Object what, int start, int end, int flags) {
      super.setSpan(what, start, end, flags);
      if (depth == 0) flush();
    }
    @Override public void removeSpan(Object what) {
      super.removeSpan(what);
      if (depth == 0) flush();
    }
  }
}
