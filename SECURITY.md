# Security Policy

## Supported Versions

RDE is pre-1.0 and moving quickly. Security fixes are provided only for the most recent released version.

| Version | Supported |
| :--- | :---: |
| Latest release (`main` / most recent tag) | ✅ |
| Older releases | ❌ |

This table will be expanded with a real support window once RDE reaches 1.0.

## What Counts as a Security Issue

Given RDE's scope — a desktop daemon suite with a privileged component (`rde-brightness` via `pkexec`/polkit) and a D-Bus surface reachable by any local session client — the following are in scope:

- Privilege escalation via `rde-brightness`'s polkit-gated sysfs writes.
- Any D-Bus method that can be called without appropriate authorization to perform a privileged action.
- Memory-safety issues in `unsafe` blocks (should be rare — flag any `unsafe` usage you find suspicious even without a working exploit).
- Path traversal or injection in `rde-config`/`rde-core`'s filesystem handling (e.g. via a maliciously crafted config or theme file).
- Denial-of-service against `rde-daemon` that can be triggered by an unprivileged local client (e.g. crashing the supervisor itself, not just one service).
- Socket permission issues on the internal `rde-ipc` Unix socket that would let another local user's process impersonate a service or the daemon.

**Not in scope**: issues requiring an attacker who already has root, or physical access to an unlocked machine — RDE assumes the same trust boundary as the rest of the user's desktop session.

## Reporting a Vulnerability

**Please do not open a public GitHub issue for security vulnerabilities.**

Instead, report privately via GitHub's [private vulnerability reporting](https://github.com/rijum8906/rde/security/advisories/new) feature on this repository. If that's unavailable, contact the maintainer directly through the contact method listed on the [GitHub profile](https://github.com/rijum8906).

Please include:

- A description of the issue and its potential impact.
- Steps to reproduce, or a minimal proof of concept if possible.
- The affected version/commit.
- Your assessment of severity, if you have one — helpful but not required.

## Response Process

1. **Acknowledgment** — you should receive a response within a few days confirming the report was received.
2. **Triage** — the maintainer will assess severity and confirm reproducibility.
3. **Fix** — a patch is developed privately. You may be asked follow-up questions or invited to verify the fix.
4. **Disclosure** — once a fix is released, a GitHub Security Advisory is published crediting the reporter (unless anonymity is requested), along with an entry in [`CHANGELOG.md`](CHANGELOG.md).

We ask that you avoid public disclosure until a fix has been released. There is currently no bug bounty program — this is a community project, but responsible disclosure is genuinely appreciated and will be credited.
