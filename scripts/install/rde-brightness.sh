# Build a release version of rde-brightness
cargo build --release --package rde-brightness

# Show installing..
echo "Installing..."

# Install rde-brightness with read, write and execute permissions
sudo install -Dm755 target/release/rde-brightness /usr/bin/rde-brightness

# The service writes brightness directly. Grant the user backlight access:
#   sudo usermod -aG video "$USER"
# and, for external monitors, access to /dev/i2c-* (commonly the i2c group).
echo "Add your user to the video group to allow direct backlight writes."

# Show finished
echo "Done!"
