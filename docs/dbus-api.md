# D-Bus API Reference

This is the **public** API surface of RDE. Each service claims its own bus name on the **session bus** and exposes its interface directly — there is no central proxy. External tools (status bars, keyboard shortcut daemons, `rde-cli`) should talk to these interfaces directly.

For the *internal* daemon↔service protocol, see [`ipc-protocol.md`](ipc-protocol.md) instead.

## Services Reference

Each service documents its own D-Bus API contracts (methods, signals, and properties) locally within its package documentation:

- **org.rde.Brightness**: Detailed API is documented in [rde-brightness README](/services/rde-brightness/README.md).
- **org.rde.Volume**: Detailed API is documented in [rde-volume](/services/rde-volume/README.md).
- **org.rde.Theme**: Detailed API is documented in [rde-theme README](/services/rde-theme/README.md).
- **org.rde.Notification**: Detailed API is documented in [rde-notification README](/services/rde-notification/README.md).

---

## Conventions

- All percentage values (`u percent`) are `0–100` unless a service explicitly documents otherwise (e.g. `rde-volume` allowing amplification above 100 if configured).
- Every mutating method emits a corresponding `*Changed` signal — clients should prefer subscribing to signals over polling `Get*` methods.
- Methods that require elevated privileges (currently only `rde-brightness`'s sysfs writes) are gated by polkit; the policy files live in [`assets/polkit/`](../assets/polkit/).
- Interfaces are additive-only within a major version — new methods/signals may be added, but existing signatures will not change without a major version bump, documented in [`CHANGELOG.md`](/CHANGELOG.md).
