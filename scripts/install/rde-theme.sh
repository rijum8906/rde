#!/usr/bin/env bash
set -e

# Build a release version of rde-theme
cargo build --release --package rde-theme

# Show installing..
echo "Installing rde-theme..."

# Install the rde-theme binary with read, write and execute permissions
sudo install -Dm755 target/release/rde-theme /usr/bin/rde-theme

# Install the polkit policy with read permissions
sudo install -Dm644 assets/polkit/org.rde.theme.policy /usr/share/polkit-1/actions/org.rde.theme.policy

# Show finished
echo "Done!"
