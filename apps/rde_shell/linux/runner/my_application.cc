#include "my_application.h"

#include <flutter_linux/flutter_linux.h>
#include <gtk-layer-shell/gtk-layer-shell.h>
#include <gdk/gdkwayland.h>
#include <cairo.h>
#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif

#include "flutter/generated_plugin_registrant.h"

struct _MyApplication
{
  GtkApplication parent_instance;
  char **dart_entrypoint_arguments;
  FlMethodChannel *input_channel;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

// Handle method calls from Dart
static void input_method_call_cb(FlMethodChannel *channel, FlMethodCall *method_call, gpointer user_data)
{
  GtkWindow *window = GTK_WINDOW(user_data);
  const gchar *method = fl_method_call_get_name(method_call);
  g_autoptr(FlValue) args = fl_method_call_get_args(method_call);

  if (strcmp(method, "setInputRegion") == 0)
  {
    if (fl_value_get_type(args) == FL_VALUE_TYPE_MAP)
    {
      FlValue *expanded_val = fl_value_lookup_string(args, "expanded");
      gboolean expanded = fl_value_get_bool(expanded_val);

      // Get the underlying GDK window (the Wayland surface)
      GdkWindow *gdk_window = gtk_widget_get_window(GTK_WIDGET(window));

      if (gdk_window != nullptr)
      {
        cairo_region_t *region = cairo_region_create();
        GdkRectangle rect;

        if (expanded)
        {
          // The whole window accepts input (bubble + expanded menu)
          rect.x = 0;
          rect.y = 0;
          rect.width = gdk_window_get_width(gdk_window);
          rect.height = gdk_window_get_height(gdk_window);
        }
        else
        {
          // Only the top 40px (the bubble) accepts input
          rect.x = 0;
          rect.y = 0;
          rect.width = gdk_window_get_width(gdk_window);
          rect.height = 40;
        }

        cairo_region_union_rectangle(region, &rect);

        // Apply the input region to the GDK window
        gdk_window_input_shape_combine_region(gdk_window, region, 0, 0);

        cairo_region_destroy(region);
      }

      fl_method_call_respond_success(method_call, nullptr, nullptr);
      return;
    }
  }
  fl_method_call_respond_not_implemented(method_call, nullptr);
}

// Called when first Flutter frame received.
static void first_frame_cb(MyApplication *self, FlView *view)
{
  gtk_widget_show(gtk_widget_get_toplevel(GTK_WIDGET(view)));
}

// Implements GApplication::activate.
static void my_application_activate(GApplication *application)
{
  MyApplication *self = MY_APPLICATION(application);
  GtkWindow *window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));

  // Shell bar should be undecorated
  gtk_window_set_decorated(window, FALSE);
  gtk_window_set_title(window, "rde_shell");

  // Support transparent background
  GdkScreen *screen = gtk_widget_get_screen(GTK_WIDGET(window));
  GdkVisual *visual = gdk_screen_get_rgba_visual(screen);
  if (visual != nullptr)
  {
    gtk_widget_set_visual(GTK_WIDGET(window), visual);
  }

  // CRITICAL: These two lines stop GTK from painting a black/white background
  gtk_widget_set_app_paintable(GTK_WIDGET(window), TRUE);
  gtk_widget_set_opacity(GTK_WIDGET(window), 1.0);

  // Fallback geometry (Layer shell will override this based on anchors)
  gtk_window_set_default_size(window, 1920, 40);

  // CRITICAL: setup layer-shell BEFORE realize
  if (gtk_layer_is_supported())
  {
    gtk_layer_init_for_window(window);

    // Anchor to top, left, and right
    gtk_layer_set_anchor(window, GTK_LAYER_SHELL_EDGE_TOP, TRUE);
    gtk_layer_set_anchor(window, GTK_LAYER_SHELL_EDGE_LEFT, TRUE);
    gtk_layer_set_anchor(window, GTK_LAYER_SHELL_EDGE_RIGHT, TRUE);

    // Set the layer to TOP (above normal windows)
    gtk_layer_set_layer(window, GTK_LAYER_SHELL_LAYER_TOP);

    // Reserve 40px of space so maximized windows don't cover the bubble
    gtk_layer_set_exclusive_zone(window, 40);

    // CRITICAL: Allow the shell to request keyboard focus when needed
    #ifdef GTK_LAYER_SHELL_KEYBOARD_MODE_ON_DEMAND
      gtk_layer_set_keyboard_mode(window, GTK_LAYER_SHELL_KEYBOARD_MODE_ON_DEMAND);
    #else
      gtk_layer_set_keyboard_interactivity(window, TRUE); // Older versions used boolean TRUE for on-demand
    #endif
  }

  gtk_widget_realize(GTK_WIDGET(window));

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(
      project, self->dart_entrypoint_arguments);

  FlView *view = fl_view_new(project);
  GdkRGBA background_color;
  gdk_rgba_parse(&background_color, "#00000000");
  fl_view_set_background_color(view, &background_color);
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));

  // Setup the Method Channel
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  self->input_channel = fl_method_channel_new(
      fl_engine_get_binary_messenger(fl_view_get_engine(view)),
      "rde_shell/input", FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(
      self->input_channel, input_method_call_cb, window, nullptr);

  // Show the window when Flutter renders.
  g_signal_connect_swapped(view, "first-frame", G_CALLBACK(first_frame_cb),
                           self);
  gtk_widget_realize(GTK_WIDGET(view));

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));

  gtk_widget_grab_focus(GTK_WIDGET(view));
}

// Implements GApplication::local_command_line.
static gboolean my_application_local_command_line(GApplication *application,
                                                  gchar ***arguments,
                                                  int *exit_status)
{
  MyApplication *self = MY_APPLICATION(application);
  // Strip out the first argument as it is the binary name.
  self->dart_entrypoint_arguments = g_strdupv(*arguments + 1);

  g_autoptr(GError) error = nullptr;
  if (!g_application_register(application, nullptr, &error))
  {
    g_warning("Failed to register: %s", error->message);
    *exit_status = 1;
    return TRUE;
  }

  g_application_activate(application);
  *exit_status = 0;

  return TRUE;
}

// Implements GApplication::startup.
static void my_application_startup(GApplication *application)
{
  G_APPLICATION_CLASS(my_application_parent_class)->startup(application);
}

// Implements GApplication::shutdown.
static void my_application_shutdown(GApplication *application)
{
  G_APPLICATION_CLASS(my_application_parent_class)->shutdown(application);
}

// Implements GObject::dispose.
static void my_application_dispose(GObject *object)
{
  MyApplication *self = MY_APPLICATION(object);
  g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
  g_clear_object(&self->input_channel);
  G_OBJECT_CLASS(my_application_parent_class)->dispose(object);
}

static void my_application_class_init(MyApplicationClass *klass)
{
  G_APPLICATION_CLASS(klass)->activate = my_application_activate;
  G_APPLICATION_CLASS(klass)->local_command_line =
      my_application_local_command_line;
  G_APPLICATION_CLASS(klass)->startup = my_application_startup;
  G_APPLICATION_CLASS(klass)->shutdown = my_application_shutdown;
  G_OBJECT_CLASS(klass)->dispose = my_application_dispose;
}

static void my_application_init(MyApplication *self) {}

MyApplication *my_application_new()
{
  g_set_prgname(APPLICATION_ID);

  return MY_APPLICATION(g_object_new(my_application_get_type(),
                                     "application-id", APPLICATION_ID, "flags",
                                     G_APPLICATION_NON_UNIQUE, nullptr));
}
