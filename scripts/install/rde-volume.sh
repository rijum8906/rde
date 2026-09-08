#!/usr/bin/env bash
set -e

# Build a release version of rde-volume
cargo build --release --package rde-volume

# Show installing..
echo "Installing rde-volume..."

# Install the rde-volume binary with read, write and execute permissions
sudo install -Dm755 target/release/rde-volume /usr/bin/rde-volume

# Install the polkit policy with read permissions
sudo install -Dm644 assets/polkit/org.rde.volume.policy /usr/share/polkit-1/actions/org.rde.volume.policy

# Show finished
echo "Done!"
