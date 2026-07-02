# Packaging Guide

This document covers how RDE is packaged for each supported distribution, and how to build/test packages locally before a release.

## Table of Contents

- [Overview](#overview)
- [Debian / Ubuntu (.deb)](#debian--ubuntu-deb)
- [Fedora / RHEL / openSUSE (.rpm)](#fedora--rhel--opensuse-rpm)
- [Arch Linux / AUR (PKGBUILD)](#arch-linux--aur-pkgbuild)
- [Release Process](#release-process)
- [Packaging Layout Decision](#packaging-layout-decision)

---

## Overview

All distro-specific metadata lives under `packaging/`, split by format:

```
packaging/
├── debian/     # apt — Debian & Ubuntu
├── rpm/        # dnf/zypper — Fedora, RHEL, openSUSE
├── arch/       # pacman/AUR — Arch, Manjaro
└── scripts/    # helper scripts used by CI to stage builds
```

Runtime assets (systemd units, polkit policies, default config) are **not** duplicated per package format — every package format installs the same files from [`assets/`](../assets/).

Packaging only runs in CI on **version tags** (`v*`), via `.github/workflows/release.yml`, kept separate from the regular `ci.yml` that runs fmt/clippy/test on every push.

---

## Debian / Ubuntu (.deb)

`dpkg-buildpackage` expects a `debian/` directory at the **repository root**, which conflicts with keeping packaging metadata organized under `packaging/`. RDE resolves this by keeping the canonical files under `packaging/debian/` and staging them to root only at build time.

### Local build

```bash
./packaging/scripts/copy-debian-to-root.sh
dpkg-buildpackage -us -uc -b
```

This produces a `.deb` in the parent directory. The staging script is intentionally simple (a copy, not a symlink) so it works identically in CI containers and on a contributor's machine.

### Key files

| File | Purpose |
| :--- | :--- |
| `control` | Package metadata, dependencies (`libasound2`, `dbus`, `policykit-1`) |
| `rules` | Build recipe — invokes `cargo build --release` per binary |
| `changelog` | Debian-format changelog, kept in sync with [`CHANGELOG.md`](../CHANGELOG.md) |
| `compat` / `copyright` | Standard Debian packaging boilerplate |

---

## Fedora / RHEL / openSUSE (.rpm)

A single `.spec` file works across all `rpm`-based distros — despite living under `rpm/` rather than a distro-specific name, it is not Fedora-only.

### Local build

```bash
rpmbuild -bb packaging/rpm/rde.spec
```

Requires `rpmdevtools` and a populated `~/rpmbuild/SOURCES/` with a source tarball matching the version in the spec's `Version:` field.

---

## Arch Linux / AUR (PKGBUILD)

Unlike Debian/RPM, the AUR is **not** "build from this repo directly" — it is its own separate git repository (`ssh://aur@aur.archlinux.org/rde.git`) containing only a `PKGBUILD` and generated `.SRCINFO`. What lives in `packaging/arch/PKGBUILD` in *this* repo is the canonical template; CI mirrors it to the AUR repo on release.

### Local build/test

```bash
cd packaging/arch
makepkg -si
```

### AUR publish (CI-driven, on tag)

1. `release.yml` bumps `pkgver`/`pkgrel` in `packaging/arch/PKGBUILD` and regenerates `.SRCINFO`.
2. Both files are pushed to the separate AUR git remote.
3. Contributors should **not** edit `.SRCINFO` by hand — it's generated from `PKGBUILD` via `makepkg --printsrcinfo`.

---

## Release Process

1. Merge to `main`, update [`CHANGELOG.md`](../CHANGELOG.md) under a new version heading.
2. Tag the release: `git tag v0.x.0 && git push --tags`.
3. `release.yml` triggers on the tag and:
   - Builds release binaries for the workspace.
   - Builds `.deb`, `.rpm`, and updates/pushes the AUR `PKGBUILD`.
   - Attaches build artifacts to the GitHub Release.
4. Verify install on at least one distro per family (Debian-based, RPM-based, Arch-based) before announcing.

---

## Packaging Layout Decision

RDE currently ships **one package (`rde`) containing all services**, rather than per-service packages (`rde-volume`, `rde-brightness`, etc.) with a meta-package pulling them in. This is the simpler option and matches the project's early-stage maturity.

Splitting into per-service packages remains an open option as the project matures — it would let users install e.g. just `rde-volume` without pulling in `rde-brightness`, which fits the project's modular design goal better, but roughly triples the packaging metadata to maintain (separate `control` stanzas / subpackages per format). Track this decision in the relevant tracking issue before changing `packaging/*` layout.
