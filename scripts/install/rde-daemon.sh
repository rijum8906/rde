# Build a release version of rde-brightness and rde-brightness-helper
cargo build --release --package rde-daemon

# Show installing..
echo "Installing..."

# Install The rde-brightness and rde-brightness-helper with read, write and execute permissions
sudo install -Dm755 target/release/rde-daemon /usr/bin/rde-daemon

# Show finished
echo "Done!"
