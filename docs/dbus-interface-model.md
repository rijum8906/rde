# RDE D-Bus Interface Model

This document defines the standard architecture for exposing services over D-Bus in RDE. All services (Theme, Brightness, Media, etc.) **must** follow this model to ensure consistency, performance, and seamless integration with Quickshell, Flutter, and external tools.

## 1. Core Philosophy

1. **Properties over Methods:** If a value can be read and written, it **must** be a D-Bus Property, not a custom Method.
2. **Automatic Signals:** Rely on `zbus` to emit `PropertiesChanged` automatically whenever a property is updated via its `set_*` method.
3. **Explicit Signals:** If a property is updated *outside* of its `set_*` method (e.g., by a background task), you must manually emit the signal using the `#[zbus(signal_emitter)]`.
4. **Strong Typing:** Never return JSON strings from D-Bus methods. Use concrete D-Bus structs (`#[derive(Type)]`) so clients can deserialize them natively.

---

## 2. Defining Properties

Properties are the primary way to expose state. In `zbus`, a read/write property requires a getter and a setter.

### The Getter

```rust
#[zbus(property)]
pub async fn appearance(&self) -> String {
    match self.service.appearance().await {
        Appearance::Light => "light".to_string(),
        Appearance::Dark => "dark".to_string(),
    }
}
```

### The Setter (Validation)

The setter **must** perform validation. If the input is invalid, return `zbus::fdo::Error::InvalidArgs`.
*Do not* emit `PropertiesChanged` manually here. `zbus` does it automatically if the setter returns `Ok(())`.

```rust
#[zbus(property)]
pub async fn set_appearance(&self, mode: String) -> zbus::fdo::Result<()> {
    let target = match mode.trim().to_lowercase().as_str() {
        "light" => Appearance::Light,
        "dark" => Appearance::Dark,
        other => return Err(zbus::fdo::Error::InvalidArgs(format!("invalid mode '{other}'"))),
    };

    self.service.set_appearance(target).await
        .map_err(|e| zbus::fdo::Error::Failed(e.to_string()))
}
```

---

## 3. Explicit Signals (The Background Task Exception)

If a property is changed by something *other* than the D-Bus setter (e.g., the system automatically switches to Dark Mode at sunset), `zbus` will **not** know about it.

In this case, you must manually emit the signal. To do this, inject the `SignalEmitter` as the last parameter of the method.

### The Pattern

```rust
#[interface(name = "org.rde.Theme")]
impl ThemeInterface {
    // 1. The method that is called by a background task
    pub async fn handle_sunset(
        &self,
        #[zbus(signal_emitter)] emitter: SignalEmitter<'_>,
    ) -> zbus::fdo::Result<()> {
        // Update the internal state
        self.service.set_appearance(Appearance::Dark).await?;

        // 2. Manually emit the PropertyChanged signal
        // zbus generates this function automatically for every property!
        self.appearance_changed(&emitter).await
            .map_err(|e| zbus::fdo::Error::Failed(e.to_string()))?;

        Ok(())
    }
}
```

*Note: The `#[zbus(signal_emitter)]` macro is only available on methods. It allows you to fire `PropertiesChanged` for specific properties.*

---

## 4. Complex Data (Structs)

If a client needs a large payload (like a full list of installed themes or a full color palette), use a Method that returns a strongly-typed Struct. Never use JSON.

### Define the Struct

```rust
use zbus::zvariant::Type;

#[derive(Serialize, Deserialize, Type, Debug)]
pub struct ResolvedTheme {
    pub primary: String,
    pub surface: String,
    // ...
}
```

### The Method

Because `zbus` flattens structs into multiple out-arguments, you must wrap the return in a 1-element tuple to force it to serialize as a single D-Bus struct value.

```rust
pub async fn get_resolved_theme(&self) -> zbus::fdo::Result<(ResolvedTheme,)> {
    let theme = self.service.current_theme().await;
    Ok((theme,))
}
```

---

## 5. Integration with XDG Desktop Portal

To make Flutter, Firefox, and GTK apps respect RDE's Dark Mode, you **must** implement the `org.freedesktop.portal.Settings` interface on the path `/org/freedesktop/portal/desktop`.

```rust
#[interface(name = "org.freedesktop.portal.Settings")]
impl PortalSettingsInterface {
    pub async fn read(&self, namespace: &str, key: &str) -> zbus::fdo::Result<OwnedVariant> {
        if namespace == "org.freedesktop.appearance" && key == "color-scheme" {
            let code: u32 = match self.service.appearance().await {
                Appearance::Dark => 1,  // 1 = Prefer Dark
                Appearance::Light => 2, // 2 = Prefer Light
            };
            Ok(OwnedVariant::from(code))
        } else {
            Err(zbus::fdo::Error::Failed("Key not found".into()))
        }
    }
}
```

When the theme changes, you must explicitly emit the `SettingChanged` signal for the portal:

```rust
if let Ok(emitter) = SignalEmitter::new(&connection, PORTAL_OBJECT_PATH) {
    let _ = PortalSettingsInterface::setting_changed(
        &emitter,
        "org.freedesktop.appearance",
        "color-scheme",
        Variant::U32(code),
    ).await;
}
```

---

## 6. Consuming the Interface (Client Side)

### Quickshell (QML)

Because RDE uses Properties, Quickshell can automatically track changes without a custom signal.

```qml
DBusProperty {
    id: modeProp
    service: "org.rde.Theme"
    path: "/org/rde/Theme"
    interface: "org.rde.Theme"
    property: "Appearance"
}

Text {
    text: modeProp.value // Auto-updates via PropertiesChanged
}
```

### Flutter (Dart)

Flutter listens to standard `PropertiesChanged` signals. It does not need a custom `ThemeChanged` listener unless it needs the massive `ResolvedTheme` struct.

```dart
final object = DBusRemoteObject(client, name: 'org.rde.Theme', path: DBusObjectPath('/org/rde/Theme'));
object.propertiesChanged.listen((changed) {
    if (changed.containsKey('Appearance')) {
        final newMode = changed['Appearance']?.asString();
        print("Appearance changed to: $newMode");
    }
});
```

---

## 7. Summary Checklist for New Interfaces

- [ ] Are all single-value states exposed as `#[zbus(property)]` with a getter and `set_` setter?
- [ ] Does the `set_` method return `InvalidArgs` on bad input?
- [ ] Are heavy operations (like updating 4 seeds at once) done via `pub async fn` Methods?
- [ ] Does the Method return a strongly-typed struct, never JSON?
- [ ] If a background task changes a property, does the method take `#[zbus(signal_emitter)]` and call `self.property_changed(&emitter).await`?
- [ ] Is the XDG Portal `color-scheme` implemented for external app compatibility?
