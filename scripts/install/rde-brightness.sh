# Build a release version of rde-brightness and rde-brightness-helper
cargo build --release --package rde-brightness

# Show installing..
echo "Installing..."

# Install The rde-brightness and rde-brightness-helper with read, write and execute permissions
sudo install -Dm755 target/release/rde-brightness /usr/bin/rde-brightness

# Install the polkit policy with read and write permissions
sudo install -Dm644 assets/polkit/org.rde.brightness.policy /usr/share/polkit-1/actions/org.rde.brightness.policy

# Show finished
echo "Done!"
