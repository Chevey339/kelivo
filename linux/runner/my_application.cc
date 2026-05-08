#include "my_application.h"

#include <flutter_linux/flutter_linux.h>
#include <gio/gio.h>
#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif

#include "flutter/generated_plugin_registrant.h"

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

static gchar* get_executable_directory() {
  gchar* executable_path = g_file_read_link("/proc/self/exe", nullptr);
  if (executable_path == nullptr) {
    return g_get_current_dir();
  }

  gchar* executable_directory = g_path_get_dirname(executable_path);
  g_free(executable_path);
  return executable_directory;
}

static GdkPixbuf* load_window_icon() {
  g_autofree gchar* executable_directory = get_executable_directory();
  g_autofree gchar* icon_path = g_build_filename(executable_directory, "data",
                                                 "flutter_assets", "assets",
                                                 "app_icon.png", nullptr);

  GError* error = nullptr;
  GdkPixbuf* icon = gdk_pixbuf_new_from_file_at_scale(icon_path, 16, 16, TRUE,
                                                      &error);
  if (icon == nullptr) {
    g_warning("Failed to load window icon: %s",
              error != nullptr ? error->message : "unknown error");
  }
  g_clear_error(&error);
  return icon;
}

// Implements GApplication::activate.
static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  GtkWindow* window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));
  gtk_window_set_icon_name(window, "kelivo");
  g_autoptr(GdkPixbuf) window_icon = load_window_icon();
  if (window_icon != nullptr) {
    gtk_window_set_icon(window, window_icon);
  }

  // Use a header bar when running in GNOME as this is the common style used
  // by applications and is the setup most users will be using (e.g. Ubuntu
  // desktop).
  // If running on X and not using GNOME then just use a traditional title bar
  // in case the window manager does more exotic layout, e.g. tiling.
  // If running on Wayland assume the header bar will work (may need changing
  // if future cases occur).
  gboolean use_header_bar = TRUE;
#ifdef GDK_WINDOWING_X11
  GdkScreen* screen = gtk_window_get_screen(window);
  if (GDK_IS_X11_SCREEN(screen)) {
    const gchar* wm_name = gdk_x11_screen_get_window_manager_name(screen);
    if (g_strcmp0(wm_name, "GNOME Shell") != 0) {
      use_header_bar = FALSE;
    }
  }
#endif
  if (use_header_bar) {
    GtkHeaderBar* header_bar = GTK_HEADER_BAR(gtk_header_bar_new());
    gtk_widget_show(GTK_WIDGET(header_bar));
    if (window_icon != nullptr) {
      GtkWidget* title_icon = gtk_image_new_from_pixbuf(window_icon);
      gtk_widget_set_size_request(title_icon, 16, 16);
      gtk_widget_show(title_icon);
      gtk_header_bar_pack_start(header_bar, title_icon);
    }
    gtk_header_bar_set_title(header_bar, "kelivo");
    gtk_header_bar_set_show_close_button(header_bar, TRUE);
    gtk_window_set_titlebar(window, GTK_WIDGET(header_bar));
  } else {
    gtk_window_set_title(window, "kelivo");
  }

  gtk_window_set_default_size(window, 1280, 720);
  gtk_widget_show(GTK_WIDGET(window));

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(project, self->dart_entrypoint_arguments);

  FlView* view = fl_view_new(project);
  gtk_widget_show(GTK_WIDGET(view));
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));

  gtk_widget_grab_focus(GTK_WIDGET(view));

  // Method channel for clipboard images
  FlEngine* engine = fl_view_get_engine(view);
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  g_autoptr(FlMethodChannel) channel = fl_method_channel_new(fl_engine_get_binary_messenger(engine),
                                                             "app.clipboard", FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(channel, [](FlMethodChannel* channel, FlMethodCall* method_call, gpointer user_data) {
    const gchar* name = fl_method_call_get_name(method_call);
    if (g_strcmp0(name, "getClipboardImages") == 0) {
      FlValue* list = fl_value_new_list();
      GtkClipboard* cb = gtk_clipboard_get(GDK_SELECTION_CLIPBOARD);
      GdkPixbuf* pixbuf = gtk_clipboard_wait_for_image(cb);
      if (pixbuf != nullptr) {
        const char* tmp = g_get_tmp_dir();
        gchar* filename = g_strdup_printf("%s/pasted_%ld.png", tmp, time(nullptr));
        GError* err = nullptr;
        gdk_pixbuf_save(pixbuf, filename, "png", &err, NULL);
        if (err == nullptr) {
          fl_value_append_take(list, fl_value_new_string(filename));
        }
        g_clear_error(&err);
        g_free(filename);
        g_object_unref(pixbuf);
      }
      g_autoptr(FlMethodResponse) response = FL_METHOD_RESPONSE(fl_method_success_response_new(list));
      fl_method_call_respond(method_call, response, nullptr);
    } else if (g_strcmp0(name, "getClipboardFiles") == 0) {
      FlValue* list = fl_value_new_list();
      GtkClipboard* cb = gtk_clipboard_get(GDK_SELECTION_CLIPBOARD);
      gchar* text = gtk_clipboard_wait_for_text(cb);
      if (text != nullptr) {
        // Common formats: "x-special/gnome-copied-files" content like:
        //   copy\nfile:///path1\nfile:///path2
        // or plain "text/uri-list" with file:// URIs per line.
        gchar** lines = g_strsplit(text, "\n", -1);
        for (gchar** it = lines; it != nullptr && *it != nullptr; ++it) {
          const gchar* line = *it;
          if (line == nullptr || *line == '\0') continue;
          if (g_strcmp0(line, "copy") == 0) continue; // GNOME prefix
          if (g_str_has_prefix(line, "file://")) {
            GFile* gf = g_file_new_for_uri(line);
            if (gf != nullptr) {
              char* path = g_file_get_path(gf);
              if (path != nullptr) {
                fl_value_append_take(list, fl_value_new_string(path));
                g_free(path);
              }
              g_object_unref(gf);
            }
          }
        }
        g_strfreev(lines);
        g_free(text);
      }
      g_autoptr(FlMethodResponse) response = FL_METHOD_RESPONSE(fl_method_success_response_new(list));
      fl_method_call_respond(method_call, response, nullptr);
    } else if (g_strcmp0(name, "setClipboardImage") == 0) {
      // Expect a file path string argument
      FlValue* args = fl_method_call_get_args(method_call);
      const gchar* path = nullptr;
      if (args != nullptr) {
        if (fl_value_get_type(args) == FL_VALUE_TYPE_STRING) {
          path = fl_value_get_string(args);
        } else if (fl_value_get_type(args) == FL_VALUE_TYPE_MAP) {
          FlValue* v = fl_value_lookup_string(args, "path");
          if (v && fl_value_get_type(v) == FL_VALUE_TYPE_STRING) {
            path = fl_value_get_string(v);
          }
        }
      }
      gboolean ok = FALSE;
      if (path != nullptr) {
        GError* err = nullptr;
        GdkPixbuf* pix = gdk_pixbuf_new_from_file(path, &err);
        if (pix != nullptr) {
          GtkClipboard* cb = gtk_clipboard_get(GDK_SELECTION_CLIPBOARD);
          gtk_clipboard_set_image(cb, pix);
          gtk_clipboard_store(cb);
          ok = TRUE;
          g_object_unref(pix);
        }
        g_clear_error(&err);
      }
      g_autoptr(FlMethodResponse) response = FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_bool(ok)));
      fl_method_call_respond(method_call, response, nullptr);
    } else {
      g_autoptr(FlMethodResponse) response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
      fl_method_call_respond(method_call, response, nullptr);
    }
  }, nullptr, nullptr);
}

// Implements GApplication::local_command_line.
static gboolean my_application_local_command_line(GApplication* application, gchar*** arguments, int* exit_status) {
  MyApplication* self = MY_APPLICATION(application);
  // Strip out the first argument as it is the binary name.
  self->dart_entrypoint_arguments = g_strdupv(*arguments + 1);

  g_autoptr(GError) error = nullptr;
  if (!g_application_register(application, nullptr, &error)) {
     g_warning("Failed to register: %s", error->message);
     *exit_status = 1;
     return TRUE;
  }

  g_application_activate(application);
  *exit_status = 0;

  return TRUE;
}

// Implements GApplication::startup.
static void my_application_startup(GApplication* application) {
  //MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application startup.

  G_APPLICATION_CLASS(my_application_parent_class)->startup(application);
}

// Implements GApplication::shutdown.
static void my_application_shutdown(GApplication* application) {
  //MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application shutdown.

  G_APPLICATION_CLASS(my_application_parent_class)->shutdown(application);
}

// Implements GObject::dispose.
static void my_application_dispose(GObject* object) {
  MyApplication* self = MY_APPLICATION(object);
  g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
  G_OBJECT_CLASS(my_application_parent_class)->dispose(object);
}

static void my_application_class_init(MyApplicationClass* klass) {
  G_APPLICATION_CLASS(klass)->activate = my_application_activate;
  G_APPLICATION_CLASS(klass)->local_command_line = my_application_local_command_line;
  G_APPLICATION_CLASS(klass)->startup = my_application_startup;
  G_APPLICATION_CLASS(klass)->shutdown = my_application_shutdown;
  G_OBJECT_CLASS(klass)->dispose = my_application_dispose;
}

static void my_application_init(MyApplication* self) {}

MyApplication* my_application_new() {
  // Set the program name to the application ID, which helps various systems
  // like GTK and desktop environments map this running application to its
  // corresponding .desktop file. This ensures better integration by allowing
  // the application to be recognized beyond its binary name.
  g_set_prgname(APPLICATION_ID);

  return MY_APPLICATION(g_object_new(my_application_get_type(),
                                     "application-id", APPLICATION_ID,
                                     "flags", G_APPLICATION_NON_UNIQUE,
                                     nullptr));
}
