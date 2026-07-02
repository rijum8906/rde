---
name: Bug report
about: Report something that isn't working as expected
title: "[BUG] "
labels: bug
assignees: ''
---

## Description

A clear description of what the bug is.

## Affected Component

- [ ] `rde-daemon`
- [ ] `rde-brightness`
- [ ] `rde-volume`
- [ ] `rde-theme`
- [ ] `rde-notification`
- [ ] `rde-cli`
- [ ] `rde-core` / `rde-config` / `rde-ipc`
- [ ] Packaging (deb / rpm / AUR)
- [ ] Other / not sure

## Steps to Reproduce

1.
2.
3.

## Expected Behavior

What you expected to happen.

## Actual Behavior

What actually happened. Include exact error messages if any.

## Environment

- **RDE version**: (`rde-cli --version`)
- **Install method**: (built from source / apt / dnf / pacman-AUR)
- **Distro & version**:
- **Desktop environment / status bar** (if relevant):

## Logs

```
Paste relevant output from `journalctl --user -u rde-daemon` or the affected service unit here.
```

## Additional Context

Anything else that might help — config file contents (redact anything sensitive), whether it's reproducible consistently, etc.
