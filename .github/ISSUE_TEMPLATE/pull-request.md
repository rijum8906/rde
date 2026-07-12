## Summary

What does this PR change, and why?

Closes #<issue-number>

## Type of Change

- [ ] Bug fix
- [ ] New feature
- [ ] New service
- [ ] D-Bus API change (see below)
- [ ] Internal IPC protocol change (see below)
- [ ] Packaging change
- [ ] Documentation only
- [ ] Refactor / no behavior change

## D-Bus / IPC Impact

- [ ] This PR does **not** change any public D-Bus interface or the internal IPC protocol.
- [ ] This PR changes a D-Bus interface — [`docs/dbus-api.md`](/docs/dbus-api.md) is updated in this PR.
- [ ] This PR changes the internal IPC protocol — [`docs/ipc-protocol.md`](/docs/ipc-protocol.md) is updated in this PR.
- [ ] This is a **breaking** change to either — noted in [`CHANGELOG.md`](/CHANGELOG.md) under `Breaking`.

## Checklist

- [ ] `cargo fmt --all` run
- [ ] `cargo clippy --workspace --all-targets -- -D warnings` passes
- [ ] `cargo test --workspace` passes
- [ ] No service crate added a dependency on another service crate
- [ ] Every new mutating D-Bus method has a corresponding `*Changed` signal (if applicable)
- [ ] Relevant docs updated (`docs/architecture.md`, `docs/dbus-api.md`, `docs/ipc-protocol.md`, `README.md`)
- [ ] `CHANGELOG.md` updated under `[Unreleased]`

## Testing

How was this tested? Include commands run and, if relevant, which distro/environment.

## Additional Notes

Anything reviewers should pay special attention to.
