package dev.kelivo.ime.driver;

import android.accessibilityservice.AccessibilityServiceInfo;
import android.app.Instrumentation;
import android.graphics.Rect;
import android.os.Bundle;
import android.os.SystemClock;
import android.view.InputDevice;
import android.view.KeyCharacterMap;
import android.view.KeyEvent;
import android.view.MotionEvent;
import android.view.accessibility.AccessibilityNodeInfo;
import android.view.accessibility.AccessibilityWindowInfo;
import java.util.ArrayList;
import java.util.List;
import org.json.JSONArray;
import org.json.JSONObject;

/** Separate test APK: drives the foreground Gboard UI without a production hook. */
public final class KeyboardDriver extends Instrumentation {
  private Bundle arguments;
  @Override public void onCreate(Bundle values) {
    super.onCreate(values); arguments = values; start();
  }

  private void collect(AccessibilityNodeInfo node, List<AccessibilityNodeInfo> result) {
    if (node == null) return;
    result.add(node);
    for (int i = 0; i < node.getChildCount(); i++) collect(node.getChild(i), result);
  }

  private AccessibilityNodeInfo find(String label) {
    List<AccessibilityNodeInfo> all = new ArrayList<>();
    for (AccessibilityWindowInfo window : getUiAutomation().getWindows()) collect(window.getRoot(), all);
    for (AccessibilityNodeInfo node : all) {
      if (!"com.google.android.inputmethod.latin".contentEquals(node.getPackageName() == null ? "" : node.getPackageName())) continue;
      if (!label.contentEquals(node.getText() == null ? "" : node.getText()) &&
          !label.contentEquals(node.getContentDescription() == null ? "" : node.getContentDescription())) continue;
      AccessibilityNodeInfo target = node;
      for (int level = 0; target != null && !target.isClickable() && level < 4; level++) target = target.getParent();
      return target != null && target.isClickable() ? target : node;
    }
    return null;
  }

  private void click(String label) throws Exception {
    AccessibilityNodeInfo node = find(label);
    for (int i = 0; node == null && i < 40; i++) { Thread.sleep(100); node = find(label); }
    if (node == null) throw new AssertionError("Gboard label missing: " + label);
    Rect bounds = new Rect(); node.getBoundsInScreen(bounds);
    long time = SystemClock.uptimeMillis();
    MotionEvent.PointerProperties pointer = new MotionEvent.PointerProperties();
    pointer.id = 0; pointer.toolType = MotionEvent.TOOL_TYPE_FINGER;
    MotionEvent.PointerCoords position = new MotionEvent.PointerCoords();
    position.x = bounds.centerX(); position.y = bounds.centerY(); position.pressure = 1; position.size = 1;
    MotionEvent.PointerProperties[] pointers = {pointer}; MotionEvent.PointerCoords[] positions = {position};
    MotionEvent down = MotionEvent.obtain(time, time, MotionEvent.ACTION_DOWN, 1, pointers, positions, 0, 0, 1, 1, 0, 0, InputDevice.SOURCE_TOUCHSCREEN, 0);
    MotionEvent up = MotionEvent.obtain(time, time + 50, MotionEvent.ACTION_UP, 1, pointers, positions, 0, 0, 1, 1, 0, 0, InputDevice.SOURCE_TOUCHSCREEN, 0);
    getUiAutomation().injectInputEvent(down, true); Thread.sleep(60); getUiAutomation().injectInputEvent(up, true);
    down.recycle(); up.recycle();
  }

  private void key(int code, int modifiers) {
    long time = SystemClock.uptimeMillis();
    getUiAutomation().injectInputEvent(new KeyEvent(time, time, KeyEvent.ACTION_DOWN, code, 0, modifiers, KeyCharacterMap.VIRTUAL_KEYBOARD, 0, 0, InputDevice.SOURCE_KEYBOARD), true);
    getUiAutomation().injectInputEvent(new KeyEvent(time, time + 1, KeyEvent.ACTION_UP, code, 0, modifiers, KeyCharacterMap.VIRTUAL_KEYBOARD, 0, 0, InputDevice.SOURCE_KEYBOARD), true);
  }

  @Override public void onStart() {
    JSONObject report = new JSONObject(); JSONArray performed = new JSONArray();
    try {
      report.put("runId", arguments.getString("run_id"));
      report.put("actions", arguments.getString("actions"));
      AccessibilityServiceInfo info = getUiAutomation().getServiceInfo();
      info.flags |= AccessibilityServiceInfo.FLAG_RETRIEVE_INTERACTIVE_WINDOWS | AccessibilityServiceInfo.FLAG_REPORT_VIEW_IDS;
      getUiAutomation().setServiceInfo(info);
      Thread.sleep(500);
      if (find("Open more stylus options") != null && find("n") == null) {
        click("Open more stylus options"); click("Show on-screen keyboard"); Thread.sleep(500);
      }
      for (String action : arguments.getString("actions", "").split("\\|")) {
        if (action.equals("@editing")) {
          if (find("Close Text Editing") == null && find("关闭文本编辑") == null) {
            for (int i = 0; find("文本编辑") == null && find("Text editing") == null && i < 10; i++) {
              if (find("打开功能菜单") != null) click("打开功能菜单");
              else if (find("Open features menu") != null) click("Open features menu");
              Thread.sleep(150);
            }
            click(find("文本编辑") != null ? "文本编辑" : "Text editing");
          }
        } else if (action.equals("@keyboard")) {
          if (find("关闭文本编辑") != null) click("关闭文本编辑");
          else if (find("Close Text Editing") != null) click("Close Text Editing");
        } else if (action.equals("@ctrlA")) {
          key(KeyEvent.KEYCODE_A, KeyEvent.META_CTRL_ON);
        } else if (action.equals("@ctrlX")) {
          key(KeyEvent.KEYCODE_X, KeyEvent.META_CTRL_ON);
        } else if (action.equals("@ctrlV")) {
          key(KeyEvent.KEYCODE_V, KeyEvent.META_CTRL_ON);
        } else if (action.equals("@ctrlZ")) {
          key(KeyEvent.KEYCODE_Z, KeyEvent.META_CTRL_ON);
        } else if (action.equals("@ctrlShiftZ")) {
          key(KeyEvent.KEYCODE_Z, KeyEvent.META_CTRL_ON | KeyEvent.META_SHIFT_ON);
        } else {
          click(action);
        }
        performed.put(action);
        if (!arguments.getString("delay", "150").equals("0")) Thread.sleep(150);
      }
      report.put("pass", true);
    } catch (Throwable error) {
      try { report.put("pass", false); report.put("error", error.toString()); } catch (Exception ignored) {}
    }
    try { report.put("performed", performed); } catch (Exception ignored) {}
    Bundle result = new Bundle(); result.putString("result", report.toString());
    finish(0, result);
  }
}
