package com.pichillilorenzo.flutter_inappwebview_android.webview;

import android.graphics.Bitmap;
import android.graphics.ColorSpace;
import android.graphics.HardwareRenderer;
import android.graphics.PixelFormat;
import android.graphics.RecordingCanvas;
import android.graphics.RenderNode;
import android.hardware.HardwareBuffer;
import android.media.Image;
import android.media.ImageReader;
import android.os.Handler;
import android.os.HandlerThread;
import android.os.Looper;
import android.os.Trace;
import android.util.Log;
import android.view.View;
import androidx.annotation.RequiresApi;
import io.flutter.plugin.common.MethodChannel;

/** Records on UI, then renders/reads a single offscreen frame off UI. No window or input host. */
@RequiresApi(29)
final class HardwareWebViewScreenshot {
  private static final Handler main = new Handler(Looper.getMainLooper());
  private static final Handler worker;
  static {
    HandlerThread thread = new HandlerThread("BrowserSnapshot");
    thread.start();
    worker = new Handler(thread.getLooper());
  }

  static void capture(View view, int x, int y, int sourceWidth, int sourceHeight,
                      int width, int height, Bitmap.CompressFormat format, int quality,
                      MethodChannel.Result result) {
    RenderNode node = new RenderNode("BrowserSnapshot");
    node.setPosition(0, 0, width, height);
    Trace.beginSection("BrowserSnapshot.record");
    try {
      RecordingCanvas canvas = node.beginRecording(width, height);
      try {
        canvas.scale((float) width / sourceWidth, (float) height / sourceHeight);
        canvas.translate(-view.getScrollX() - x, -view.getScrollY() - y);
        view.draw(canvas);
      } finally {
        node.endRecording();
      }
    } catch (RuntimeException error) {
      node.discardDisplayList();
      result.success(null);
      Log.w("BrowserSnapshot", "Recording failed", error);
      return;
    } finally {
      Trace.endSection();
    }
    worker.post(() -> render(node, width, height, format, quality, result));
  }

  private static void render(RenderNode node, int width, int height,
                             Bitmap.CompressFormat format, int quality,
                             MethodChannel.Result result) {
    Bitmap pixels = null;
    Trace.beginSection("BrowserSnapshot.render");
    try (ImageReader reader = ImageReader.newInstance(width, height,
        PixelFormat.RGBA_8888, 2,
        HardwareBuffer.USAGE_GPU_SAMPLED_IMAGE | HardwareBuffer.USAGE_GPU_COLOR_OUTPUT)) {
      HardwareRenderer renderer = new HardwareRenderer();
      try {
        renderer.setName("BrowserSnapshot");
        renderer.setOpaque(false);
        renderer.setSurface(reader.getSurface());
        renderer.setContentRoot(node);
        int status = renderer.createRenderRequest().setWaitForPresent(true).syncAndDraw();
        if ((status & (HardwareRenderer.SYNC_FRAME_DROPPED |
                HardwareRenderer.SYNC_LOST_SURFACE_REWARD_IF_FOUND |
                HardwareRenderer.SYNC_CONTEXT_IS_STOPPED)) == 0) {
          // Consume the only submitted frame immediately. Never leave a producer
          // rendering into an undrained ImageReader on the shared RenderThread.
          try (Image image = reader.acquireLatestImage()) {
            if (image != null) {
              try (HardwareBuffer buffer = image.getHardwareBuffer()) {
                if (buffer != null) {
                  Bitmap hardware = Bitmap.wrapHardwareBuffer(buffer,
                      ColorSpace.get(ColorSpace.Named.SRGB));
                  if (hardware != null) {
                    try {
                      pixels = hardware.copy(Bitmap.Config.ARGB_8888, false);
                    } finally {
                      hardware.recycle();
                    }
                  }
                }
              }
            }
          }
        }
      // Stop the producer before closing its consumer, including failure paths.
      } finally {
        renderer.destroy();
      }
    } catch (RuntimeException error) {
      Log.w("BrowserSnapshot", "Rendering failed", error);
    } finally {
      node.discardDisplayList();
      Trace.endSection();
    }
    if (pixels == null) main.post(() -> result.success(null));
    else WebViewScreenshot.encode(pixels, format, quality, result);
  }

  private HardwareWebViewScreenshot() {}
}
