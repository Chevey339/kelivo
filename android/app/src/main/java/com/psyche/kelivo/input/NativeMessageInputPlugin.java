package com.psyche.kelivo.input;

import android.app.Activity;
import android.content.Context;
import android.text.InputType;
import android.view.View;
import android.view.ViewGroup;
import android.view.KeyEvent;
import android.view.inputmethod.EditorInfo;
import android.view.inputmethod.InputConnection;
import android.view.inputmethod.InputMethodManager;
import android.widget.FrameLayout;
import androidx.core.view.inputmethod.EditorInfoCompat;
import androidx.core.view.inputmethod.InputConnectionCompat;
import io.flutter.embedding.engine.systemchannels.TextInputChannel;
import org.json.JSONObject;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;

public final class NativeMessageInputPlugin implements MethodChannel.MethodCallHandler {
  Activity activity;
  final MethodChannel channel;
  final HostView host;
  final InputMethodManager imm;
  final Map<MirrorConnection,TextInputChannel.Configuration> configurations = new HashMap<>();
  final Map<String,MirrorConnection> documents = new HashMap<>();
  final HashSet<PendingReply> pendingReplies = new HashSet<>();
  MirrorConnection connection;

  public NativeMessageInputPlugin(Context context, BinaryMessenger messenger) {
    channel = new MethodChannel(messenger, "kelivo/native_message_input");
    channel.setMethodCallHandler(this);
    Context application = context.getApplicationContext();
    imm = (InputMethodManager) application.getSystemService(Context.INPUT_METHOD_SERVICE);
    // The cached Flutter engine owns this view and document. An Activity must
    // never be retained by a BaseInputConnection across Activity recreation.
    host = new HostView(application);
  }

  public void attachActivity(Activity next) {
    if (activity == next) return;
    if (activity != null) detachActivity(activity);
    activity = next;
    next.getWindow().getDecorView().post(() -> {
      if (activity != next) return;
      next.addContentView(host, new FrameLayout.LayoutParams(1,1));
      if (connection != null && connection.canAccept()) showInput();
    });

  }

  public void detachActivity(Activity previous) {
    if (activity != previous) return;
    activity = null;
    if (connection != null) connection.retireInputHandles();
    host.handledKeys.clear();
    host.clearFocus();
    if (host.getParent() instanceof ViewGroup) ((ViewGroup)host.getParent()).removeView(host);
  }

  void showInput() {
    if (activity == null || !host.isAttachedToWindow()) return;
    host.requestFocus();
    imm.restartInput(host);
    imm.showSoftInput(host,InputMethodManager.SHOW_IMPLICIT);
  }

  void endInput(MirrorConnection document) {
    document.retireInputHandles();
    if (connection != document) return;
    connection = null;
    host.handledKeys.clear();
    host.clearFocus();
    View flutterView = activity == null ? null : activity.findViewById(io.flutter.embedding.android.FlutterActivity.FLUTTER_VIEW_ID);
    if (flutterView != null) { flutterView.requestFocus(); imm.restartInput(flutterView); }
  }

  // A navigation error must also settle RPCs queued behind that navigation.
  // Keep accepted document work queued: reporting an error is not discarding it.
  final class PendingReply {
    final MirrorConnection document;
    final MethodChannel.Result result;
    boolean settled;
    PendingReply(MirrorConnection document, MethodChannel.Result result) {
      this.document=document;this.result=result;
      pendingReplies.add(this);
      if(document.navigationError!=null) fail(document.navigationError);
    }
    void success(Object value) {
      if(settled)return;settled=true;pendingReplies.remove(this);result.success(value);
    }
    void fail(String message) {
      if(settled)return;settled=true;pendingReplies.remove(this);result.error("mirror",message,null);
    }
  }
  void navigationFailed(MirrorConnection document, long serial, String message) {
    if(!document.valid||!document.navigationPending||document.navigationSerial!=serial)return;
    document.navigationError=message;
    for(PendingReply reply:new java.util.ArrayList<>(pendingReplies)) {
      if(reply.document==document)reply.fail(message);
    }
    channel.invokeMethod("failure",Map.of("session",document.session,"error",message));
  }

  void configure(MirrorConnection document, Map<String,Object> values) throws Exception {
    TextInputChannel.Configuration configuration=TextInputChannel.Configuration.fromJson(new JSONObject(values));
    configurations.put(document,configuration);
    document.mimeTypes=configuration.contentCommitMimeTypes;
  }

  void configureHardware(MirrorConnection document, Map<String,Object> values) {
    String enter=(String)values.get("enter");
    if(!java.util.Set.of("newline","send","controlSend").contains(enter))throw new IllegalArgumentException("Unknown Enter behavior");
    HashSet<String> commands=new HashSet<>();
    for(Object command:(List<?>)values.get("commands")) {
      if(!java.util.Set.of("paste","escape","undo","redo","submit").contains(command))throw new IllegalArgumentException("Unknown owner command");
      commands.add((String)command);
    }
    document.enterMode=enter;
    document.ownerCommands.clear();
    document.ownerCommands.addAll(commands);
  }

  int integer(MethodCall call,String key) { return ((Number)call.argument(key)).intValue(); }
  @Override public void onMethodCall(MethodCall call, MethodChannel.Result result) {
    try {
      if (call.method.equals("open")) {
        String id=call.argument("session");
        if(documents.containsKey(id)) throw new IllegalStateException("Document already open");
        MirrorConnection document = new MirrorConnection(host,id,call.argument("text"),integer(call,"base"),integer(call,"extent"),
          event -> channel.invokeMethod("event",event));
        document.selectionSink = () -> {
          if(host.isAttachedToWindow() && connection == document)
            imm.updateSelection(host,document.base(),document.extent(),document.composingStart(),document.composingEnd());
        };
        configure(document,call.argument("configuration"));
        configureHardware(document,call.argument("hardware"));
        document.interactionSink = event -> channel.invokeMethod((String)event.get("type"),event);
        documents.put(id,document);
        document.navigationSink = request -> channel.invokeMethod("navigate",request,new MethodChannel.Result() {
          @Override public void success(Object value) {
            if(!document.valid) return;
            Map<?,?> response=(Map<?,?>)value;
            document.completeNavigation(((Number)request.get("serial")).longValue(),
              ((Number)response.get("base")).intValue(),((Number)response.get("extent")).intValue(),(String)response.get("affinity"));
          }
          @Override public void error(String code,String message,Object details) {
            navigationFailed(document,((Number)request.get("serial")).longValue(),"Navigation failed: "+message);
          }
          @Override public void notImplemented() { error("navigation","No document layout resolver",null); }
        });
        result.success(null);
        return;
      }
      MirrorConnection document=documents.get(call.<String>argument("session"));
      if(document == null) {
        if(call.method.equals("endInput")||call.method.equals("hide")) { result.success(null); return; }
        throw new IllegalStateException("Unknown native document");
      }
      switch(call.method) {
        case "hardware": configureHardware(document,call.argument("configuration")); break;
        case "command": {
          String name=call.argument("command");
          if(!document.canAccept()||!document.ownerCommands.contains(name))throw new IllegalStateException("Owner command unavailable");
          document.ownerCommand(name,((Number)call.argument("request")).longValue());
          break;
        }
        case "show":
          if(!document.canAccept()) throw new IllegalStateException("Document is closing");
          if(connection != document) {
            if(connection != null) endInput(connection);
            connection=document;
            showInput();
          } else if(host.isAttachedToWindow()) {
            imm.showSoftInput(host,InputMethodManager.SHOW_IMPLICIT);
          }
          break;
        case "configure":
          configure(document,call.argument("configuration"));
          if(connection==document && host.isAttachedToWindow()) {
            document.retireInputHandles();
            imm.restartInput(host);
          }
          break;
        case "hide":
          if(connection == document) imm.hideSoftInputFromWindow(host.getWindowToken(),0);
          break;
        case "endInput": endInput(document); break;
        case "close": {
          PendingReply reply=new PendingReply(document,result);
          if(reply.settled)return;
          endInput(document);
          document.closeWhenDrained(revision -> {
            documents.remove(document.session);
            configurations.remove(document);
            reply.success(Map.of("revision",revision));
          });
          return;
        }
        case "flush": {
          if(!document.canAccept()) throw new IllegalStateException("Document is closing");
          PendingReply reply=new PendingReply(document,result);
          if(reply.settled)return;
          document.executeOrQueue(() -> {
            document.forcePublish();
            reply.success(Map.of("revision",document.revision));
          });
          return;
        }
        case "edit": {
          PendingReply reply=new PendingReply(document,result);
          if(reply.settled)return;
          List<Number> selected=call.argument("selection"), composing=call.argument("composing");
          document.applyAppEdit(((Number)call.argument("revision")).longValue(),((Number)call.argument("request")).longValue(),
            call.argument("patches"),selected.get(0).intValue(),selected.get(1).intValue(),composing.get(0).intValue(),composing.get(1).intValue(),reply::success,error -> reply.fail(error.toString()));
          return;
        }
        default: result.notImplemented(); return;
      }
      result.success(null);
    } catch(Exception error) { result.error("mirror",error.toString(),null); }
  }

  final class HostView extends View {
    final HashSet<Integer> handledKeys = new HashSet<>();
    SessionInputConnection activeInput;
    HostView(Context context) {
      super(context);
      setFocusable(true); setFocusableInTouchMode(true);
      setImportantForAccessibility(IMPORTANT_FOR_ACCESSIBILITY_NO_HIDE_DESCENDANTS);
    }
    @Override public boolean dispatchKeyEvent(KeyEvent event) {
      if(connection != null) {
        if(event.getAction()==KeyEvent.ACTION_DOWN && connection.sendKeyEvent(event)) {
          handledKeys.add(event.getKeyCode()); return true;
        }
        if(event.getAction()==KeyEvent.ACTION_UP && handledKeys.remove(event.getKeyCode())) {
          connection.sendKeyEvent(event); return true;
        }
      }
      return super.dispatchKeyEvent(event);
    }
    @Override public boolean onCheckIsTextEditor() { return connection != null && connection.canAccept(); }
    @Override public InputConnection onCreateInputConnection(EditorInfo info) {
      if(!onCheckIsTextEditor()) return null;
      info.inputType=InputType.TYPE_CLASS_TEXT|InputType.TYPE_TEXT_FLAG_MULTI_LINE;
      info.imeOptions=EditorInfo.IME_ACTION_NONE|EditorInfo.IME_FLAG_NO_EXTRACT_UI;
      TextInputChannel.Configuration configuration=configurations.get(connection);
      if(configuration!=null) {
        info.imeOptions=configuration.inputAction|EditorInfo.IME_FLAG_NO_EXTRACT_UI;
        if(!configuration.enableIMEPersonalizedLearning)info.imeOptions|=EditorInfo.IME_FLAG_NO_PERSONALIZED_LEARNING;
        if(configuration.autocorrect)info.inputType|=InputType.TYPE_TEXT_FLAG_AUTO_CORRECT;
        if(!configuration.enableSuggestions)info.inputType|=InputType.TYPE_TEXT_FLAG_NO_SUGGESTIONS;
        if(configuration.obscureText)info.inputType|=InputType.TYPE_TEXT_VARIATION_PASSWORD;
        switch(configuration.textCapitalization) {
          case CHARACTERS:info.inputType|=InputType.TYPE_TEXT_FLAG_CAP_CHARACTERS;break;
          case WORDS:info.inputType|=InputType.TYPE_TEXT_FLAG_CAP_WORDS;break;
          case SENTENCES:info.inputType|=InputType.TYPE_TEXT_FLAG_CAP_SENTENCES;break;
          default:break;
        }
        info.actionLabel=configuration.actionLabel;info.actionId=configuration.inputAction;
        if(configuration.hintLocales!=null)info.hintLocales=new android.os.LocaleList(configuration.hintLocales);
      }
      EditorInfoCompat.setContentMimeTypes(info,connection.mimeTypes);
      info.initialSelStart=connection.base(); info.initialSelEnd=connection.extent();
      if(android.os.Build.VERSION.SDK_INT>=30) info.setInitialSurroundingText(connection.text);
      // A query does not retire a previously returned, still-served handle.
      activeInput=new SessionInputConnection(this,connection);
      SessionInputConnection handle=activeInput;
      return InputConnectionCompat.createWrapper(handle,info,(content,flags,opts) ->
        !handle.closed && handle.document.insertContent(content,flags));
    }
  }
}
