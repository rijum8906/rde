# Changelog

All notable changes to this project are documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/) once it reaches 1.0.0. Before 1.0.0, minor version bumps (`0.x.0`) may include breaking changes to the D-Bus API or internal IPC protocol — check the entry for a **Breaking** note.

## [Unreleased]

### Added
- Initial workspace scaffold: `rde-daemon`, `rde-brightness`, `rde-volume`, `rde-theme`, `rde-notification`, `rde-cli`, and shared `rde-core` / `rde-config` / `rde-ipc` crates.
- D-Bus interfaces for brightness, volume, and theme services.
- Internal daemon↔service supervision protocol over Unix domain socket.
- Debian, RPM, and Arch (AUR) packaging metadata.

### Notes
- `rde-notification` is work-in-progress; its `org.freedesktop.Notifications` implementation is stubbed pending the notification rendering surface.

---

## Release Template

When cutting a release, copy this structure and move the relevant `[Unreleased]` entries under the new version heading:

```
## [0.x.0] - YYYY-MM-DD

### Added
-

### Changed
-

### Fixed
-

### Breaking
-
```
