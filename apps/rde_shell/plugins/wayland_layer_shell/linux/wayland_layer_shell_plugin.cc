#include "include/wayland_layer_shell/wayland_layer_shell_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>
#include <sys/utsname.h>

#include <cstring>

#include "wayland_layer_shell_plugin_private.h"

#include <gdk/gdkwayland.h>
#include <gtk-layer-shell/gtk-layer-shell.h>
#include <wayland-client.h>
#include "iostream"

#define WAYLAND_LAYER_SHELL_PLUGIN(obj)                                     \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), wayland_layer_shell_plugin_get_type(), \
                              WaylandLayerShellPlugin))

struct _WaylandLayerShellPlugin
{
  GObject parent_instance;
  FlPluginRegistrar *registrar;
};

G_DEFINE_TYPE(WaylandLayerShellPlugin, wayland_layer_shell_plugin, g_object_get_type())

GtkWindow *get_window(WaylandLayerShellPlugin *self)
{
  FlView *view = fl_plugin_registrar_get_view(self->registrar);
  if (view == nullptr)
    return nullptr;

  return GTK_WINDOW(gtk_widget_get_toplevel(GTK_WIDGET(view)));
}

static FlMethodResponse *is_supported(WaylandLayerShellPlugin *self)
{
  if (gtk_layer_is_supported() == 0)
  {
    GtkWindow *gtk_window = get_window(self);
    gtk_widget_show(GTK_WIDGET(gtk_window));
  }
  g_autoptr(FlValue) result =
      fl_value_new_bool(gtk_layer_is_supported());
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

static FlMethodResponse *initialize(WaylandLayerShellPlugin *self, FlValue *args)
{
  g_autoptr(FlValue) result;
  GtkWindow *gtk_window = get_window(self);
  if (gtk_layer_is_supported() == 0)
  {
    result = fl_value_new_bool(false);
  }
  else
  {
    int width = fl_value_get_int(fl_value_lookup_string(args, "width"));
    int height = fl_value_get_int(fl_value_lookup_string(args, "height"));
    gtk_widget_set_size_request(GTK_WIDGET(gtk_window), width, height);
    gtk_layer_init_for_window(gtk_window);
    result = fl_value_new_bool(true);
  }

  gtk_widget_show(GTK_WIDGET(gtk_window));
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

static FlMethodResponse *set_layer(WaylandLayerShellPlugin *self, FlValue *args)
{
  int layer = fl_value_get_int(fl_value_lookup_string(args, "layer"));
  gtk_layer_set_layer(get_window(self), static_cast<GtkLayerShellLayer>(layer));
  g_autoptr(FlValue) result = fl_value_new_bool(true);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

static FlMethodResponse *get_layer(WaylandLayerShellPlugin *self)
{
  g_autoptr(FlValue) result = fl_value_new_int(gtk_layer_get_layer(get_window(self)));
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

static FlMethodResponse *get_monitor_list(WaylandLayerShellPlugin *self)
{
  GdkDisplay *display = gdk_display_get_default();
  g_autoptr(FlValue) result = fl_value_new_list();
  for (int i = 0; i < gdk_display_get_n_monitors(display); i++)
  {
    GdkMonitor *monitor = gdk_display_get_monitor(display, i);
    gchar *val = g_strdup_printf("%i:%s", i, gdk_monitor_get_model(monitor));
    fl_value_append_take(result, fl_value_new_string(val));
  }
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

static FlMethodResponse *set_monitor(WaylandLayerShellPlugin *self, FlValue *args)
{
  GdkDisplay *display = gdk_display_get_default();
  int id = fl_value_get_int(fl_value_lookup_string(args, "id"));

  if (id == -1)
  {
    gtk_layer_set_monitor(get_window(self), NULL);

    g_autoptr(FlValue) result = fl_value_new_bool(true);
    return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
  }

  GdkMonitor *monitor = gdk_display_get_monitor(display, id);
  gtk_layer_set_monitor(get_window(self), monitor);

  g_autoptr(FlValue) result = fl_value_new_bool(true);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

static FlMethodResponse *set_anchor(WaylandLayerShellPlugin *self, FlValue *args)
{
  int edge = fl_value_get_int(fl_value_lookup_string(args, "edge"));
  gboolean anchor_to_edge = fl_value_get_bool(fl_value_lookup_string(args, "anchor_to_edge"));

  gtk_layer_set_anchor(get_window(self), static_cast<GtkLayerShellEdge>(edge), anchor_to_edge);
  g_autoptr(FlValue) result = fl_value_new_bool(true);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

static FlMethodResponse *get_anchor(WaylandLayerShellPlugin *self, FlValue *args)
{
  int edge = fl_value_get_int(fl_value_lookup_string(args, "edge"));
  g_autoptr(FlValue) result = fl_value_new_bool(gtk_layer_get_anchor(get_window(self), static_cast<GtkLayerShellEdge>(edge)));
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

static FlMethodResponse *set_margin(WaylandLayerShellPlugin *self, FlValue *args)
{
  int edge = fl_value_get_int(fl_value_lookup_string(args, "edge"));
  int margin_size = fl_value_get_int(fl_value_lookup_string(args, "margin_size"));

  gtk_layer_set_margin(get_window(self), static_cast<GtkLayerShellEdge>(edge), margin_size);
  g_autoptr(FlValue) result = fl_value_new_bool(true);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

static FlMethodResponse *get_margin(WaylandLayerShellPlugin *self, FlValue *args)
{
  int edge = fl_value_get_int(fl_value_lookup_string(args, "edge"));
  g_autoptr(FlValue) result = fl_value_new_int(gtk_layer_get_margin(get_window(self), static_cast<GtkLayerShellEdge>(edge)));
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

static FlMethodResponse *set_exclusive_zone(WaylandLayerShellPlugin *self, FlValue *args)
{
  int exclusive_zone = fl_value_get_int(fl_value_lookup_string(args, "exclusive_zone"));
  gtk_layer_set_exclusive_zone(get_window(self), exclusive_zone);
  g_autoptr(FlValue) result = fl_value_new_bool(true);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

static FlMethodResponse *get_exclusive_zone(WaylandLayerShellPlugin *self)
{
  g_autoptr(FlValue) result = fl_value_new_int(gtk_layer_get_exclusive_zone(get_window(self)));
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

static FlMethodResponse *enable_auto_exclusive_zone(WaylandLayerShellPlugin *self)
{
  gtk_layer_auto_exclusive_zone_enable(get_window(self));
  g_autoptr(FlValue) result = fl_value_new_bool(true);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

static FlMethodResponse *is_auto_exclusive_zone_enabled(WaylandLayerShellPlugin *self)
{
  g_autoptr(FlValue) result = fl_value_new_bool(gtk_layer_auto_exclusive_zone_is_enabled(get_window(self)));
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

static FlMethodResponse *set_keyboard_mode(WaylandLayerShellPlugin *self, FlValue *args)
{
  int keyboard_mode = fl_value_get_int(fl_value_lookup_string(args, "keyboard_mode"));
  gtk_layer_set_keyboard_mode(get_window(self), static_cast<GtkLayerShellKeyboardMode>(keyboard_mode));
  g_autoptr(FlValue) result = fl_value_new_bool(true);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

static FlMethodResponse *get_keyboard_mode(WaylandLayerShellPlugin *self)
{
  g_autoptr(FlValue) result = fl_value_new_int(gtk_layer_get_keyboard_mode(get_window(self)));
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

// Returns the struct wl_surface backing the layer window, or NULL when the
// window is not a Wayland surface (e.g. X11 fallback).
static struct wl_surface *get_wl_surface(WaylandLayerShellPlugin *self)
{
  GtkWindow *gtk_window = get_window(self);
  if (gtk_window == nullptr)
    return nullptr;

  GdkWindow *gdk_window = gtk_widget_get_window(GTK_WIDGET(gtk_window));
  if (gdk_window == nullptr || !GDK_IS_WAYLAND_WINDOW(gdk_window))
    return nullptr;

  return gdk_wayland_window_get_wl_surface(gdk_window);
}

// Globals used to locate the wl_compositor for creating empty input regions.

// Callback issued for every global advertised by the Wayland registry; we bind
// the wl_compositor once and stash it in the registry carry data.
static void registry_handle_global(void *data, struct wl_registry *registry,
                                   uint32_t name, const char *interface,
                                   uint32_t version)
{
  struct wl_compositor **compositor = static_cast<struct wl_compositor **>(data);
  if (strcmp(interface, wl_compositor_interface.name) == 0)
  {
    *compositor = static_cast<struct wl_compositor *>(
        wl_registry_bind(registry, name, &wl_compositor_interface, 4));
  }
}

static void registry_handle_global_remove(void *data, struct wl_registry *registry,
                                          uint32_t name)
{
}

static const struct wl_registry_listener compositor_listener = {
    registry_handle_global,
    registry_handle_global_remove,
};

// Returns a bound wl_compositor for the given display, or NULL on failure.
static struct wl_compositor *get_compositor(WaylandLayerShellPlugin *self)
{
  GdkDisplay *display = gtk_widget_get_display(GTK_WIDGET(get_window(self)));
  if (!GDK_IS_WAYLAND_DISPLAY(display))
    return nullptr;

  struct wl_display *wl_display = gdk_wayland_display_get_wl_display(display);
  if (wl_display == nullptr)
    return nullptr;

  struct wl_compositor *compositor = nullptr;
  struct wl_registry *registry = wl_display_get_registry(wl_display);
  wl_registry_add_listener(registry, &compositor_listener, &compositor);
  wl_display_roundtrip(wl_display);
  wl_display_roundtrip(wl_display);
  wl_registry_destroy(registry);

  return compositor;
}

// Controls the clickable (input) region of the layer surface.
//
// The args map may contain:
//   - no "rect": the whole surface accepts input (input region cleared).
//   - "rect": {x, y, height} describing a rectangle in surface coordinates
//     (width is taken from the window's allocated width). Only this rectangle
//     receives pointer/touch input; everything outside passes through to the
//     surfaces underneath (e.g. the desktop behind a transparent panel).
static FlMethodResponse *set_input_region(WaylandLayerShellPlugin *self, FlValue *args)
{
  struct wl_surface *surface = get_wl_surface(self);
  GdkDisplay *display = gtk_widget_get_display(GTK_WIDGET(get_window(self)));
  struct wl_display *wl_display = nullptr;
  if (GDK_IS_WAYLAND_DISPLAY(display))
  {
    wl_display = gdk_wayland_display_get_wl_display(display);
  }

  if (surface != nullptr && wl_display != nullptr)
  {
    FlValue *rect = fl_value_lookup_string(args, "rect");
    if (rect == nullptr)
    {
      // A NULL input region means "infinite" (whole surface) input.
      wl_surface_set_input_region(surface, nullptr);
    }
    else
    {
      int x = fl_value_get_int(fl_value_lookup_string(rect, "x"));
      int y = fl_value_get_int(fl_value_lookup_string(rect, "y"));
      int height = fl_value_get_int(fl_value_lookup_string(rect, "height"));
      int width = gtk_widget_get_allocated_width(GTK_WIDGET(get_window(self)));
      struct wl_compositor *compositor = get_compositor(self);
      if (compositor != nullptr)
      {
        // Build an input region with a single rectangle; the compositor
        // intersects it with the surface bounds automatically.
        struct wl_region *region = wl_compositor_create_region(compositor);
        wl_region_add(region, x, y, width, height);
        wl_surface_set_input_region(surface, region);
        wl_region_destroy(region);
        wl_compositor_destroy(compositor);
      }
    }
    wl_display_flush(wl_display);
  }

  g_autoptr(FlValue) result = fl_value_new_bool(true);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

// Resizes the layer surface to @height logical pixels, keeping its width
// (which is driven by the anchored left/right edges).
//
// This lets a top-anchored panel start as a compact 40px bar and expand
// downward on hover to reveal a pop-up card, then collapse back to the bar
// when the pointer leaves.
static FlMethodResponse *set_surface_height(WaylandLayerShellPlugin *self, FlValue *args)
{
  int height = fl_value_get_int(fl_value_lookup_string(args, "height"));

  GtkWindow *gtk_window = get_window(self);
  int width = gtk_widget_get_allocated_width(GTK_WIDGET(gtk_window));
  gtk_window_resize(gtk_window, width, height);
  gtk_widget_set_size_request(GTK_WIDGET(gtk_window), -1, height);

  // Push the size change to the compositor so the anchored layer surface is
  // re-configured at the new height.
  GdkDisplay *display = gtk_widget_get_display(GTK_WIDGET(gtk_window));
  if (GDK_IS_WAYLAND_DISPLAY(display))
  {
    struct wl_display *wl_display = gdk_wayland_display_get_wl_display(display);
    if (wl_display != nullptr)
    {
      wl_display_flush(wl_display);
    }
  }

  g_autoptr(FlValue) result = fl_value_new_bool(true);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

// Called when a method call is received from Flutter.
static void wayland_layer_shell_plugin_handle_method_call(
    WaylandLayerShellPlugin *self,
    FlMethodCall *method_call)
{
  g_autoptr(FlMethodResponse) response = nullptr;

  const gchar *method = fl_method_call_get_name(method_call);
  FlValue *args = fl_method_call_get_args(method_call);

  if (strcmp(method, "getPlatformVersion") == 0)
  {
    response = get_platform_version();
  }
  else if (strcmp(method, "isSupported") == 0)
  {
    response = is_supported(self);
  }
  else if (strcmp(method, "initialize") == 0)
  {
    response = initialize(self, args);
  }
  else if (strcmp(method, "setLayer") == 0)
  {
    response = set_layer(self, args);
  }
  else if (strcmp(method, "getLayer") == 0)
  {
    response = get_layer(self);
  }
  else if (strcmp(method, "getMonitorList") == 0)
  {
    response = get_monitor_list(self);
  }
  else if (strcmp(method, "setMonitor") == 0)
  {
    response = set_monitor(self, args);
  }
  else if (strcmp(method, "setAnchor") == 0)
  {
    response = set_anchor(self, args);
  }
  else if (strcmp(method, "getAnchor") == 0)
  {
    response = get_anchor(self, args);
  }
  else if (strcmp(method, "setMargin") == 0)
  {
    response = set_margin(self, args);
  }
  else if (strcmp(method, "getMargin") == 0)
  {
    response = get_margin(self, args);
  }
  else if (strcmp(method, "setExclusiveZone") == 0)
  {
    response = set_exclusive_zone(self, args);
  }
  else if (strcmp(method, "getExclusiveZone") == 0)
  {
    response = get_exclusive_zone(self);
  }
  else if (strcmp(method, "enableAutoExclusiveZone") == 0)
  {
    response = enable_auto_exclusive_zone(self);
  }
  else if (strcmp(method, "isAutoExclusiveZoneEnabled") == 0)
  {
    response = is_auto_exclusive_zone_enabled(self);
  }
  else if (strcmp(method, "setKeyboardMode") == 0)
  {
    response = set_keyboard_mode(self, args);
  }
  else if (strcmp(method, "getKeyboardMode") == 0)
  {
    response = get_keyboard_mode(self);
  }
  else if (strcmp(method, "setInputRegion") == 0)
  {
    response = set_input_region(self, args);
  }
  else if (strcmp(method, "setSurfaceHeight") == 0)
  {
    response = set_surface_height(self, args);
  }
  else
  {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }

  fl_method_call_respond(method_call, response, nullptr);
}

FlMethodResponse *get_platform_version()
{
  struct utsname uname_data = {};
  uname(&uname_data);
  g_autofree gchar *version = g_strdup_printf("Linux %s", uname_data.version);
  g_autoptr(FlValue) result = fl_value_new_string(version);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

static void wayland_layer_shell_plugin_dispose(GObject *object)
{
  G_OBJECT_CLASS(wayland_layer_shell_plugin_parent_class)->dispose(object);
}

static void wayland_layer_shell_plugin_class_init(WaylandLayerShellPluginClass *klass)
{
  G_OBJECT_CLASS(klass)->dispose = wayland_layer_shell_plugin_dispose;
}

static void wayland_layer_shell_plugin_init(WaylandLayerShellPlugin *self) {}

static void method_call_cb(FlMethodChannel *channel, FlMethodCall *method_call,
                           gpointer user_data)
{
  WaylandLayerShellPlugin *plugin = WAYLAND_LAYER_SHELL_PLUGIN(user_data);
  wayland_layer_shell_plugin_handle_method_call(plugin, method_call);
}

void wayland_layer_shell_plugin_register_with_registrar(FlPluginRegistrar *registrar)
{
  WaylandLayerShellPlugin *plugin = WAYLAND_LAYER_SHELL_PLUGIN(
      g_object_new(wayland_layer_shell_plugin_get_type(), nullptr));

  plugin->registrar = FL_PLUGIN_REGISTRAR(g_object_ref(registrar));

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  g_autoptr(FlMethodChannel) channel =
      fl_method_channel_new(fl_plugin_registrar_get_messenger(registrar),
                            "wayland_layer_shell",
                            FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(channel, method_call_cb,
                                            g_object_ref(plugin),
                                            g_object_unref);

  g_object_unref(plugin);
}
