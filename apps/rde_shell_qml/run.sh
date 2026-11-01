#!/usr/bin/env bash
# Launches the RDE shell with the bundled M3Shapes QML module on the import path.
#
# M3Shapes is a C++ QML plugin built locally into ./M3Shapes, so Qt has to be
# told where to find that module. Running `quickshell -p shell.qml` directly
# fails with: module "M3Shapes" is not installed.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export QML2_IMPORT_PATH="${here}${QML2_IMPORT_PATH:+:${QML2_IMPORT_PATH}}"

exec quickshell -p "${here}/shell.qml" "$@"
