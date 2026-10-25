package com.pichillilorenzo.flutter_inappwebview_android.webview;

import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.os.Handler;
import android.os.Build;
import android.os.Trace;
import android.os.Looper;
import android.view.View;
import android.util.Log;
import java.io.ByteArrayOutputStream;
import java.util.Map;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import io.flutter.plugin.common.MethodChannel;

/** Capture requested pixels; visible GPU views render/read/encode off the UI thread. */
public final class WebViewScreenshot {
  private static final ExecutorService encoder = Executors.newSingleThreadExecutor();
  private static final Handler main = new Handler(Looper.getMainLooper());

  public static void capture(View view, Map<String, Object> configuration,
                             float density, MethodChannel.Result result) {
    Bitmap bitmap = null;
    try {
      int x = 0, y = 0, width = view.getMeasuredWidth(), height = view.getMeasuredHeight();
      Bitmap.CompressFormat format = Bitmap.CompressFormat.PNG;
      int quality = 100;
      Number snapshotWidth = null;
      if (configuration != null) {
        Map<String, Number> rect = (Map<String, Number>) configuration.get("rect");
        if (rect != null) {
          x = Math.round(rect.get("x").floatValue() * density);
          y = Math.round(rect.get("y").floatValue() * density);
          width = Math.min(width - x, Math.round(rect.get("width").floatValue() * density));
          height = Math.min(height - y, Math.round(rect.get("height").floatValue() * density));
        }
        snapshotWidth = (Number) configuration.get("snapshotWidth");
        if (configuration.get("compressFormat") != null) {
          format = Bitmap.CompressFormat.valueOf((String) configuration.get("compressFormat"));
        }
        if (configuration.get("quality") != null) quality = ((Number) configuration.get("quality")).intValue();
      }
      if (x < 0 || y < 0 || width <= 0 || height <= 0) {
        result.success(null);
        return;
      }
      int targetWidth = snapshotWidth == null ? width : Math.round(snapshotWidth.floatValue() * density);
      int targetHeight = Math.max(1, Math.round((float) height * targetWidth / width));
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q && view.isHardwareAccelerated() && view.isShown()) {
        HardwareWebViewScreenshot.capture(view, x, y, width, height,
            targetWidth, targetHeight, format, quality, result);
        return;
      }
      bitmap = Bitmap.createBitmap(targetWidth, targetHeight, Bitmap.Config.ARGB_8888);
      Canvas canvas = new Canvas(bitmap);
      canvas.scale((float) targetWidth / width, (float) targetHeight / height);
      canvas.translate(-view.getScrollX() - x, -view.getScrollY() - y);
      view.draw(canvas);
      encode(bitmap, format, quality, result);
    } catch (IllegalArgumentException error) {
      if (bitmap != null) bitmap.recycle();
      result.success(null);
    }
  }

  static void encode(Bitmap pixels, Bitmap.CompressFormat format, int quality,
                     MethodChannel.Result result) {
    encoder.execute(() -> {
      byte[] bytes = null;
      Trace.beginSection("BrowserSnapshot.encode");
      try {
        ByteArrayOutputStream output = new ByteArrayOutputStream();
        if (pixels.compress(format, quality, output)) bytes = output.toByteArray();
      } catch (RuntimeException error) {
        Log.w("WebViewScreenshot", "Screenshot encoding failed", error);
      } finally {
        pixels.recycle();
        Trace.endSection();
        final byte[] encoded = bytes;
        main.post(() -> result.success(encoded));
      }
    });
  }

  private WebViewScreenshot() {}
}
